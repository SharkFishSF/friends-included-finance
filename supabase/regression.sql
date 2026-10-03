-- Run after schema.sql. All test records and delivery jobs roll back.
begin;
do $$
declare t jsonb; v integer; denied boolean;
begin
 t:=public.submit_record('richard','{"kind":"sale","reference":"REGRESSION_SALE","description":"Rollback test","amount_cents":100000,"customer":"Test customer","project":"A","proposed_split":[50,30,20]}','website');
 denied:=false;
 begin perform public.approve_record('richard','REGRESSION_SALE','{"split":[50,30,20]}'); exception when others then denied:=true; end;
 if not denied then raise exception 'FAIL Richard approval accepted'; end if;
 denied:=false;
 begin perform public.submit_record('kevin','{"kind":"sale","reference":"REGRESSION_BAD","description":"Test","amount_cents":100,"customer":"Test","project":"A","proposed_split":[100,0,0]}','website'); exception when others then denied:=true; end;
 if not denied then raise exception 'FAIL Kevin sale accepted'; end if;
 denied:=false;
 begin perform public.submit_record('richard','{"kind":"sale","reference":"REGRESSION_SPLIT","description":"Test","amount_cents":100,"customer":"Test","project":"A","proposed_split":[60,30,20]}','website'); exception when others then denied:=true; end;
 if not denied then raise exception 'FAIL Invalid split accepted'; end if;
 denied:=false;
 begin perform public.submit_record('kevin','{"kind":"expense","reference":"REGRESSION_ZERO","description":"Test","amount_cents":0,"category":"Travel","proposed_allocation":"A"}','website'); exception when others then denied:=true; end;
 if not denied then raise exception 'FAIL Zero expense accepted'; end if;
 denied:=false;
 begin perform public.submit_record('richard','{"kind":"sale","reference":"REGRESSION_SALE","description":"Duplicate","amount_cents":100000,"customer":"Test","project":"A","proposed_split":[50,30,20]}','website'); exception when unique_violation then denied:=true; end;
 if not denied then raise exception 'FAIL Duplicate reference accepted'; end if;
 t:=public.approve_record('svetlana','REGRESSION_SALE','{"split":[20,40,40]}');
 v:=(t->>'version')::integer;
 t:=public.approve_record('svetlana','REGRESSION_SALE','{"split":[100,0,0]}');
 if (t->>'version')::integer<>v or t->'final_split'<>'[20,40,40]'::jsonb or t->'proposed_split'<>'[50,30,20]'::jsonb then raise exception 'FAIL Approval idempotency or proposal preservation'; end if;
 if (select count(*) from public.outbox where reference='REGRESSION_SALE' and event='decision' and channel='sheets')<>1 then raise exception 'FAIL Duplicate approval delivery'; end if;
 insert into public.telegram_accounts(user_id,chat_id) values('regression-user','regression-chat');
 perform public.link_employee('svetlana','regression-user','richard');
 t:=public.submit_record('richard','{"kind":"sale","reference":"REGRESSION_BOT","description":"Test","amount_cents":100,"customer":"Test","project":"A","proposed_split":[100,0,0]}','telegram','regression-chat',-1);
 perform public.link_employee('svetlana','regression-user','kevin');
 t:=public.approve_record('svetlana','REGRESSION_BOT','{"split":[100,0,0]}');
 if t->>'employee'<>'richard' or t->>'recipient_chat'<>'regression-chat' then raise exception 'FAIL Bot destination changed after relink'; end if;
 raise notice 'Database permission, uniqueness, idempotency and relink tests passed';
end $$;
rollback;
