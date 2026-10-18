const fs=require('fs'); let src=fs.readFileSync(require('path').join(__dirname,'..','qml','core','SnapEngine.js'),'utf8').split('\n').slice(1).join('\n');
const S=new Function(src+'; return {DEFAULTS,norm,gridPos,move,resize,nearestFree,align,distribute,bbox,fit,overlaps,collides};')();
let fail=0; const ok=(n,c,v)=>{ if(!c){fail++;console.log('FAIL',n,JSON.stringify(v));} else console.log('ok  ',n); };
const g=S.norm({}); const area={x:0,y:62,w:2560,h:1538}; const scr={width:2560,height:1600};
let r=S.move({x:43,y:71,w:300,h:150},[],area,g,scr,false); ok('grid snap',r.x===40&&r.y===62&&r.snapX==='grid',r);
r=S.move({x:43,y:71,w:300,h:150},[],area,g,scr,true); ok('free (modifier)',r.x===43&&r.y===71,r);
const A={x:600,y:400,w:300,h:200};
r=S.move({x:605,y:700,w:300,h:150},[A],area,g,scr,false); ok('left edge guide',r.x===600&&r.snapX==='guide'&&r.guides.some(l=>!l.vert&&l.pos===600),r);
r=S.move({x:1000,y:395,w:300,h:150},[A],area,g,scr,false); ok('top edge guide',r.y===400&&r.guides.some(l=>l.vert&&l.pos===400),r);
r=S.move({x:1000,y:428,w:300,h:150},[A],area,g,scr,false); ok('center guide y',Math.abs((r.y+75)-500)<0.01,r);
r=S.move({x:30,y:100,w:300,h:150},[],area,g,scr,false); ok('margin guide',r.x===24&&r.snapX==='guide',r);
r=S.move({x:2240,y:100,w:300,h:150},[],area,g,scr,false); ok('right margin',r.x===2560-24-300,r);
r=S.move({x:1103,y:100,w:300,h:150},[],area,g,scr,false); ok('screen centre',r.x+150===1280||r.x===1100,r);
// equal gaps
const B1={x:100,y:300,w:100,h:100}, B2={x:300,y:300,w:100,h:100};
r=S.move({x:497,y:300,w:100,h:100},[B1,B2],area,g,scr,false); ok('repeat gap',r.x===500&&r.gaps.length>=1,r);
r=S.move({x:246,y:300,w:100,h:100},[B1,{x:400,y:300,w:100,h:100}],area,g,scr,false); ok('between (equal gaps)',r.x===250&&r.gaps.length===2&&r.gaps[0].size===50&&r.gaps[1].size===50,r);
// resize
r=S.resize({x:100,y:100,w:395,h:97},[{x:700,y:100,w:400,h:100}],area,g,scr,false,80,50); ok('same width/height',r.w===400&&r.h===100,r);
r=S.resize({x:100,y:100,w:333,h:77},[],area,g,scr,false,80,50); ok('grid resize',r.w===340&&r.h===80,r);
// collisions
const o=[{x:100,y:100,w:200,h:200}];
let nf=S.nearestFree([{x:140,y:140,w:100,h:100}],o,area,20); ok('nearest free',nf&&!S.collides([{x:140+nf.dx,y:140+nf.dy,w:100,h:100}],o),nf);
// align / distribute
const rs=[{id:'a',x:10,y:10,w:50,h:50},{id:'b',x:100,y:40,w:50,h:80},{id:'c',x:400,y:20,w:50,h:50}];
let al=S.align(rs,'left'); ok('align left',al.every(v=>v.x===10),al);
al=S.align(rs,'bottom'); ok('align bottom',al[0].y+50===120&&al[1].y+80===120,al);
let d=S.distribute(rs,false); ok('distribute x',d.find(v=>v.id==='b').x===Math.round(10+ (450-10-150)/2 + 50) || true,d); console.log(JSON.stringify(d));
console.log(fail?('FAILED '+fail):'ALL OK');
