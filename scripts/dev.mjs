import http from 'node:http';
import {readFile} from 'node:fs/promises';
import {resolve,extname} from 'node:path';
import app from '../api/app.js';
import bot from '../api/telegram.js';
const root=resolve('public');
http.createServer(async(req,res)=>{res.status=n=>(res.statusCode=n,res);res.json=o=>res.end(JSON.stringify(o));try{const url=new URL(req.url,'http://localhost');if(url.pathname.startsWith('/api/')){let body='';for await(const chunk of req){body+=chunk;if(body.length>20000)throw new Error('Request too large');}req.body=body?JSON.parse(body):{};res.setHeader('Content-Type','application/json');return await (url.pathname==='/api/telegram'?bot:app)(req,res);}const path=resolve(root,'.'+(url.pathname==='/'?'/index.html':url.pathname));if(!path.startsWith(root+'\\')&&!path.startsWith(root+'/'))throw new Error('Invalid path');res.setHeader('Content-Type',({'.html':'text/html; charset=utf-8','.js':'application/javascript; charset=utf-8','.css':'text/css; charset=utf-8','.svg':'image/svg+xml'})[extname(path)]||'application/octet-stream');res.end(await readFile(path));}catch{res.statusCode=404;res.end('Not found');}}).listen(3000,'127.0.0.1',()=>console.log('Friends Included: http://127.0.0.1:3000'));
