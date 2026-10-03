-- Run once in the Supabase SQL Editor. No browser key can access these records.
create sequence public.sales_row start 2;
create sequence public.expenses_row start 2;
create table public.telegram_accounts(user_id text primary key, chat_id text not null, employee text check(employee in ('svetlana','richard','anastasia','jean','kevin')), started_at timestamptz not null default now());
create unique index employee_telegram_link on public.telegram_accounts(employee) where employee is not null;
create table public.transactions(
 reference text primary key, kind text not null check(kind in ('sale','expense')), employee text not null,
 submitted_at timestamptz not null default now(), description text not null, amount_cents bigint not null check(amount_cents>0 and amount_cents<=100000000000),
 customer text, project text check(project in ('A','B')), category text check(category in ('Materials','Travel','Other')),
 proposed_split jsonb, final_split jsonb, proposed_allocation text check(proposed_allocation in ('A','B','Overhead')), final_allocation text check(final_allocation in ('A','B','Overhead')),
 status text not null, origin text not null, recipient_chat text, sheet_row bigint not null, version integer not null default 1,
 decided_at timestamptz, sync_status text not null default 'Sync pending', notification_status text not null default 'Pending', sync_error text, notification_error text);
create table public.outbox(id bigint generated always as identity primary key, reference text not null references public.transactions(reference), version integer not null, channel text not null check(channel in ('sheets','telegram')), event text not null, payload jsonb not null, state text not null default 'pending', attempts integer not null default 0, error text, lease_until timestamptz, unique(reference,version,channel,event));
create table public.telegram_updates(update_id bigint primary key, completed boolean not null default false);
alter table public.transactions enable row level security;
alter table public.telegram_accounts enable row level security;
alter table public.outbox enable row level security;
alter table public.telegram_updates enable row level security;
revoke all on public.transactions,public.telegram_accounts,public.outbox,public.telegram_updates from anon,authenticated;

create function public.valid_split(s jsonb) returns boolean language sql immutable as $$
 select jsonb_typeof(s)='array' and jsonb_array_length(s)=3 and not exists(select 1 from jsonb_array_elements(s) x where jsonb_typeof(x)<>'number' or (x::text)::numeric<0 or (x::text)::numeric>100) and abs((select sum((x::text)::numeric) from jsonb_array_elements(s) x)-100)<0.000001
$$;
create function public.queue_record(t public.transactions, ev text) returns void language plpgsql as $$
begin
 insert into public.outbox(reference,version,channel,event,payload) values(t.reference,t.version,'sheets',ev,to_jsonb(t)) on conflict do nothing;
 if t.recipient_chat is not null then insert into public.outbox(reference,version,channel,event,payload) values(t.reference,t.version,'telegram',ev,to_jsonb(t)) on conflict do nothing; end if;
end $$;
create function public.submit_record(actor text, data jsonb, source text, chat text default null, telegram_update bigint default null) returns jsonb language plpgsql as $$
declare t public.transactions; recipient text;
begin
 if telegram_update is not null and exists(select 1 from public.telegram_updates where update_id=telegram_update) then return jsonb_build_object('duplicate_update',true); end if;
 if source not in ('website','telegram') then raise exception 'Invalid source'; end if;
 if (data->>'kind'='sale' and actor not in ('richard','anastasia','jean')) or (data->>'kind'='expense' and actor<>'kevin') then raise exception 'Role cannot submit this transaction'; end if;
 if data->>'kind' not in ('sale','expense') or coalesce(data->>'reference','') !~ '^[A-Z0-9][A-Z0-9_-]{0,39}$' or length(trim(coalesce(data->>'description','')))=0 then raise exception 'Missing required transaction information'; end if;
 if data->>'kind'='sale' and (coalesce(data->>'customer','')='' or coalesce(data->>'project','') not in ('A','B') or not coalesce(public.valid_split(data->'proposed_split'),false)) then raise exception 'Invalid sale or split'; end if;
 if data->>'kind'='expense' and (coalesce(data->>'category','') not in ('Materials','Travel','Other') or coalesce(data->>'proposed_allocation','') not in ('A','B','Overhead')) then raise exception 'Invalid expense'; end if;
 if source='telegram' then recipient:=chat; else select chat_id into recipient from public.telegram_accounts where employee=actor; end if;
 insert into public.transactions(reference,kind,employee,description,amount_cents,customer,project,category,proposed_split,proposed_allocation,final_allocation,status,origin,recipient_chat,sheet_row,notification_status)
 values(data->>'reference',data->>'kind',actor,data->>'description',(data->>'amount_cents')::bigint,data->>'customer',data->>'project',data->>'category',data->'proposed_split',data->>'proposed_allocation',case when data->>'proposed_allocation'='Overhead' then 'Overhead' end,case when data->>'kind'='sale' then 'Pending approval' when data->>'proposed_allocation'='Overhead' then 'Allocated' else 'Awaiting allocation' end,source,recipient,case when data->>'kind'='sale' then nextval('public.sales_row') else nextval('public.expenses_row') end,case when recipient is null then 'No Telegram recipient linked' else 'Pending' end) returning * into t;
 perform public.queue_record(t,'submission');
 if telegram_update is not null then insert into public.telegram_updates values(telegram_update,true); end if;
 return to_jsonb(t);
end $$;
create function public.approve_record(actor text, ref text, decision jsonb) returns jsonb language plpgsql as $$
declare t public.transactions; recipient text;
begin
 if actor<>'svetlana' then raise exception 'Only Svetlana can approve'; end if;
 select * into t from public.transactions where reference=ref for update;
 if not found then raise exception 'Unknown reference'; end if;
 if t.status in ('Approved','Allocated') then return to_jsonb(t); end if;
 if t.kind='sale' then
 if not coalesce(public.valid_split(decision->'split'),false) then raise exception 'Invalid split'; end if;
 t.final_split:=decision->'split'; t.status:='Approved';
 else
 if coalesce(decision->>'allocation','') not in ('A','B','Overhead') then raise exception 'Invalid allocation'; end if;
 t.final_allocation:=decision->>'allocation'; t.status:='Allocated';
 end if;
 -- Bot destinations are immutable; website entries can gain a linked destination before approval.
 recipient:=t.recipient_chat;
 if t.origin='website' and recipient is null then select chat_id into recipient from public.telegram_accounts where employee=t.employee; end if;
 update public.transactions set final_split=t.final_split,final_allocation=t.final_allocation,status=t.status,decided_at=now(),version=version+1,recipient_chat=recipient,sync_status='Sync pending',notification_status=case when recipient is null then 'No Telegram recipient linked' else 'Pending' end where reference=ref returning * into t;
 perform public.queue_record(t,'decision'); return to_jsonb(t);
end $$;
create function public.link_employee(actor text, uid text, person text) returns void language plpgsql as $$
begin
 if actor<>'svetlana' then raise exception 'Only Svetlana can link employees'; end if;
 if person not in ('svetlana','richard','anastasia','jean','kevin') then raise exception 'Unknown employee'; end if;
 if not exists(select 1 from public.telegram_accounts where user_id=uid) then raise exception 'This user must first start the bot'; end if;
 update public.telegram_accounts set employee=null where employee=person or user_id=uid;
 update public.telegram_accounts set employee=person where user_id=uid;
end $$;
create function public.claim_delivery(job_id bigint) returns jsonb language plpgsql as $$
declare j public.outbox;
begin
 -- Serialize jobs for a reference, so an older sheet revision cannot overwrite an approval.
 perform pg_advisory_xact_lock(hashtext((select reference from public.outbox where id=job_id)));
 if exists(select 1 from public.outbox where reference=(select reference from public.outbox where id=job_id) and state='processing' and lease_until>now()) then return null; end if;
 update public.outbox set state='processing',attempts=attempts+1,lease_until=now()+interval '90 seconds' where id=job_id and (state in ('pending','failed') or (state='processing' and lease_until<now())) returning * into j;
 return case when j.id is null then null else to_jsonb(j) end;
end $$;
create function public.finish_delivery(job_id bigint, failure text default null) returns void language plpgsql as $$
declare j public.outbox;
begin
 update public.outbox set state=case when failure is null then 'sent' else 'failed' end,error=failure,lease_until=null where id=job_id returning * into j;
 if j.channel='sheets' then update public.transactions set sync_status=case when failure is null then 'Synced' else 'Sync failed' end,sync_error=failure where reference=j.reference and version=j.version;
 else update public.transactions set notification_status=case when failure is null then 'Sent' else 'Notification failed' end,notification_error=failure where reference=j.reference and version=j.version; end if;
end $$;
-- Postgres grants EXECUTE to PUBLIC by default. Restrict every app function.
revoke execute on function public.valid_split(jsonb),public.queue_record(public.transactions,text),public.submit_record(text,jsonb,text,text,bigint),public.approve_record(text,text,jsonb),public.link_employee(text,text,text),public.claim_delivery(bigint),public.finish_delivery(bigint,text) from public,anon,authenticated;
grant execute on function public.valid_split(jsonb),public.queue_record(public.transactions,text),public.submit_record(text,jsonb,text,text,bigint),public.approve_record(text,text,jsonb),public.link_employee(text,text,text),public.claim_delivery(bigint),public.finish_delivery(bigint,text) to service_role;
