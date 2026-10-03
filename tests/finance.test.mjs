import test from 'node:test';
import assert from 'node:assert/strict';
import {submission,commissions,dashboard,assertRole,notification} from '../lib/domain.js';
import {sheetRow} from '../lib/delivery.js';
function sale(reference,employee,project,amount,split){return {...submission(employee,{kind:'sale',reference,customer:'Fictional customer',description:'Wedding guests',project,amount,split}),status:'Pending approval'};}
function expense(reference,amount,allocation){return {...submission('kevin',{kind:'expense',reference,description:'Fictional expense',category:'Materials',amount,allocation}),status:allocation==='Overhead'?'Allocated':'Awaiting allocation',final_allocation:allocation==='Overhead'?'Overhead':null};}
const approve=(t,split)=>Object.assign(t,{status:'Approved',final_split:split});
const allocate=(t,a)=>Object.assign(t,{status:'Allocated',final_allocation:a});
test('both complete homework scenarios reconcile from transaction data',()=>{
const s1=sale('S01','richard','A','1000',[50,30,20]),s2=sale('S02','anastasia','B','2000',[0,50,50]),e1=expense('E01','120','A'),e2=expense('E02','80','B'),e3=expense('E03','100','Overhead');const all=[s1,s2,e1,e2,e3];let d=dashboard(all);assert.equal(d.result,-30000);assert.equal(d.A.result,0);assert.equal(d.B.result,0);assert.equal(d.income,0);assert.equal(d.commissions,0);
approve(s1,[50,30,20]);approve(s2,[20,40,40]);allocate(e1,'A');allocate(e2,'A');d=dashboard(all);assert.equal(d.A.result,70000);assert.equal(d.B.result,180000);assert.equal(d.result,240000);assert.deepEqual(d.earned,[9000,11000,10000]);
const s3=sale('S03','jean','A','1500',[40,40,20]),s4=sale('S04','richard','B','800',[25,25,50]),s5=sale('S05','richard','B','600',[100,0,0]),e4=expense('E04','250','B'),e5=expense('E05','90','A'),e6=expense('E06','60','Overhead'),e7=expense('E07','140','A');all.push(s3,s4,s5,e4,e5,e6,e7);approve(s3,[20,30,50]);approve(s4,[25,25,50]);allocate(e4,'B');allocate(e5,'B');d=dashboard(all);assert.equal(d.A.result,205000);assert.equal(d.B.result,218000);assert.equal(d.result,393000);assert.equal(d.overhead,16000);assert.equal(d.awaiting,14000);assert.equal(d.pendingSales,60000);assert.deepEqual(d.earned,[14000,17500,21500]);assert.equal(d.A.result+d.B.result-d.overhead-d.awaiting,d.result);assert.deepEqual(dashboard(all),dashboard(all));
assert.match(notification(s3,'decision'),/changed/);assert.match(notification(s3,'decision'),/€150.00/);assert.match(notification(e5,'decision'),/Proposed: A. Approved: B/);
});
test('submission permissions and validation run in the processing layer',()=>{
assert.throws(()=>sale('S99','kevin','A','100',[100,0,0]),/cannot/);assert.throws(()=>assertRole('richard',['svetlana']),/cannot/);assert.throws(()=>sale('S99','richard','A','100',[60,30,20]),/total/);for(const amount of ['',0,-1,'1.234','NaN','Infinity'])assert.throws(()=>expense('E99',amount,'A'));assert.throws(()=>sale('','richard','A','100',[100,0,0]),/reference/);assert.throws(()=>submission('kevin',{kind:'expense',reference:'E99',amount:'100',allocation:'A',category:'Materials'}),/Description/);
});
test('cent rounding allocates residual to largest share with deterministic ties',()=>{
assert.deepEqual(commissions(100,[35,35,30]),{pool:10,earned:[3,4,3]});assert.deepEqual(commissions(105,[0,50,50]),{pool:11,earned:[0,5,6]});for(let amount=1;amount<2000;amount++){const c=commissions(amount,[33.33,33.33,33.34]);assert.equal(c.earned.reduce((a,b)=>a+b,0),c.pool);}
});
test('pending Sheets rows show proposals and zero earned commissions',()=>{
const s=sale('S01','richard','A','1000',[50,30,20]);const row=sheetRow(s);assert.deepEqual(row.slice(7,10),[50,30,20]);assert.deepEqual(row.slice(10,13),['','','']);assert.deepEqual(row.slice(13,16),[0,0,0]);approve(s,[20,30,50]);assert.deepEqual(sheetRow(s).slice(13,16),[20,30,50]);
});
