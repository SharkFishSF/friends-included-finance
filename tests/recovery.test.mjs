import test from 'node:test';
import assert from 'node:assert/strict';
import {generateKeyPairSync} from 'node:crypto';
import {drain} from '../lib/delivery.js';
import app from '../api/app.js';
test('interrupted Sheets and Telegram deliveries preserve decisions and retry the same row',async()=>{
const oldFetch=globalThis.fetch,oldEnv={...process.env};const {privateKey}=generateKeyPairSync('rsa',{modulusLength:2048,privateKeyEncoding:{type:'pkcs8',format:'pem'},publicKeyEncoding:{type:'spki',format:'pem'}});
Object.assign(process.env,{SUPABASE_URL:'https://database.test',SUPABASE_SERVICE_ROLE_KEY:'test',GOOGLE_SERVICE_ACCOUNT_EMAIL:'test@example.com',GOOGLE_PRIVATE_KEY:privateKey,GOOGLE_SHEET_ID:'test-sheet',TELEGRAM_BOT_TOKEN:'test'});
const record={reference:'S99',kind:'sale',status:'Approved',employee:'richard',submitted_at:'2026-10-03T12:00:00Z',amount_cents:100000,project:'A',customer:'Fictional',description:'Wedding',proposed_split:[50,30,20],final_split:[20,30,50],recipient_chat:'123',sheet_row:12,version:2};
const jobs=[{id:1,reference:'S99',version:2,channel:'sheets',event:'decision',payload:record,state:'pending'},{id:2,reference:'S99',version:2,channel:'telegram',event:'decision',payload:record,state:'pending'}];let failing=true;const writes=[];
globalThis.fetch=async(url,options={})=>{const body=options.body?JSON.parse(typeof options.body==='string'?options.body:'{}'):{};const reply=(data,status=200)=>({ok:status<400,status,json:async()=>data});
if(url.includes('/outbox?'))return reply(jobs.filter(j=>j.state!=='sent'));
if(url.includes('/transactions?'))return reply([record]);
if(url.endsWith('/rpc/claim_delivery')){const j=jobs.find(x=>x.id===body.job_id);if(j.state==='sent')return reply(null);j.state='processing';return reply({...j});}
if(url.endsWith('/rpc/finish_delivery')){const j=jobs.find(x=>x.id===body.job_id);j.state=body.failure?'failed':'sent';record[j.channel==='sheets'?'sync_status':'notification_status']=body.failure?(j.channel==='sheets'?'Sync failed':'Notification failed'):(j.channel==='sheets'?'Synced':'Sent');return reply(null);}
if(url==='https://oauth2.googleapis.com/token')return reply({access_token:'test'});
if(url.includes('sheets.googleapis.com')){writes.push(body.data[1]);return reply({},failing?503:200);}
if(url.includes('api.telegram.org'))return reply(failing?{ok:false,description:'Recipient blocked the bot'}:{ok:true},failing?403:200);
throw new Error('Unexpected test URL');};
try{await drain('S99');assert.equal(record.status,'Approved');assert.equal(record.amount_cents,100000);assert.equal(record.sync_status,'Sync failed');assert.equal(record.notification_status,'Notification failed');failing=false;await drain('S99');assert.equal(record.sync_status,'Synced');assert.equal(record.notification_status,'Sent');assert.equal(writes.length,2);assert.equal(writes[0].range,'Sales!A12:Q12');assert.equal(writes[1].range,writes[0].range);assert.equal(writes[1].values[0][0],'S99');await drain('S99');assert.equal(writes.length,2);}finally{globalThis.fetch=oldFetch;for(const k of Object.keys(process.env))if(!(k in oldEnv))delete process.env[k];Object.assign(process.env,oldEnv);}
});
test('HTTP processing denies unauthorized actions before touching the database',async()=>{
for(const [role,body] of [['richard',{action:'approve',reference:'S01',split:[100,0,0]}],['kevin',{action:'submit',kind:'sale'}],['richard',{action:'link',user_id:'123',employee:'svetlana'}]]){let result,status;const res={setHeader(){},status(n){status=n;return this;},json(d){result=d;return this;}};await app({method:'POST',headers:{'x-demo-role':role},body},res);assert.equal(status,400);assert.match(result.error,/cannot/);}
});
