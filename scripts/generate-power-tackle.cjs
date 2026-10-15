// Original motion curves; only rig rest transforms/names come from installed mesh metadata.
// No source animation, mesh vertices, texture, or game events are exported.
const fs=require('fs'),path=require('path');
const game=process.argv[2];
if(!game) throw Error('Pass installed Project Zomboid directory');
const rig=fs.readFileSync(path.join(game,'media/models_X/Skinned/MaleBody.x'),'utf8');
const names=['Bip01','Bip01_Pelvis','Bip01_Spine','Bip01_Spine1','Bip01_Neck','Bip01_Head',
 'Bip01_L_Clavicle','Bip01_L_UpperArm','Bip01_L_Forearm','Bip01_L_Hand',
 'Bip01_R_Clavicle','Bip01_R_UpperArm','Bip01_R_Forearm','Bip01_R_Hand'];
const parents=[-1,0,1,2,3,4,4,6,7,8,4,10,11,12];
function mul(a,b){return [a[3]*b[0]+a[0]*b[3]+a[1]*b[2]-a[2]*b[1],a[3]*b[1]-a[0]*b[2]+a[1]*b[3]+a[2]*b[0],a[3]*b[2]+a[0]*b[1]-a[1]*b[0]+a[2]*b[3],a[3]*b[3]-a[0]*b[0]-a[1]*b[1]-a[2]*b[2]];}
function axis(i,degrees){let q=[0,0,0,Math.cos(degrees*Math.PI/360)];q[i]=Math.sin(degrees*Math.PI/360);return q;}
function quaternion(m){
 // .x row-vector matrix transposed into quaternion column-vector convention.
 const a=[m[0],m[4],m[8],m[1],m[5],m[9],m[2],m[6],m[10]],t=a[0]+a[4]+a[8];let q,s;
 if(t>0){s=Math.sqrt(t+1)*2;q=[(a[7]-a[5])/s,(a[2]-a[6])/s,(a[3]-a[1])/s,s/4];}
 else {let i=a[4]>a[0]?1:0;if(a[8]>a[i*3+i])i=2;let j=(i+1)%3,k=(i+2)%3;s=Math.sqrt(1+a[i*3+i]-a[j*3+j]-a[k*3+k])*2;q=[0,0,0,0];q[i]=s/4;q[j]=(a[j*3+i]+a[i*3+j])/s;q[k]=(a[k*3+i]+a[i*3+k])/s;q[3]=(a[k*3+j]-a[j*3+k])/s;}
 const l=Math.hypot(...q);return q.map(v=>v/l);
}
const bones=names.map(name=>{const match=new RegExp('Frame '+name+' \\{\\s*FrameTransformMatrix \\{\\s*([^;]+)').exec(rig);if(!match)throw Error(name);const m=match[1].split(',').map(Number);return {name,p:m.slice(12,15),q:quaternion(m)};});
// Anticipation -> right shoulder leads -> small hold -> return. Upright spine;
// no pelvis/root channels, no translation impulse, no extended-hand push.
const phases=[[0,0],[.09,-.20],[.23,1],[.31,1],[.43,.45],[.56,0]];
function pose(b,w){let q=b.q;
 const apply=(i,d)=>{q=mul(q,axis(i,d));};
 if(b.name==='Bip01_Spine'){apply(0,20*w);apply(1,-4*w);}
 if(b.name==='Bip01_Spine1'){apply(0,14*w);apply(1,-3*w);}
 if(b.name==='Bip01_Neck')apply(0,-18*w);
 if(b.name==='Bip01_Head')apply(0,-8*w);
 if(b.name.endsWith('_R_Clavicle'))apply(1,8*w);
 if(b.name.endsWith('_L_Clavicle'))apply(1,-5*w);
 // Constant tucked guard during this overlay, plus small shoulder contraction.
 if(b.name.endsWith('_UpperArm')){apply(2,b.name.includes('_R_')?-12:-8);apply(1,-6*w);}
 if(b.name.endsWith('_Forearm'))apply(1,-100-8*w);
 return q;
}
const out=['1','PS_PowerTackle','6',...Array(13).fill('0'),'0','','0','',String(bones.length)];
bones.forEach((b,i)=>out.push(String(i),String(parents[i]),b.name));out.push('');
for(const label of ['BindPose','InverseBindPose','Offsets']){out.push(label);for(const b of bones)out.push('1,0,0,0','0,1,0,0','0,0,1,0','0,0,0,1','');}
out.push('1','PS_PowerTackle','.56',String((bones.length-2)*phases.length));
const fmt=v=>v.map(n=>Math.abs(n)<1e-9?'0':n.toFixed(9)).join(',');
for(const [t,w] of phases)for(let i=2;i<bones.length;i++){let b=bones[i];out.push(String(i),b.name,String(t),fmt(b.p),fmt(pose(b,w)));}
const dest=path.join(__dirname,'../Contents/mods/PlayableSoccer/42/media/anims/ps_powertackle.txt');
fs.mkdirSync(path.dirname(dest),{recursive:true});fs.writeFileSync(dest,out.join('\n')+'\n');
const marker=path.join(__dirname,'../Contents/mods/PlayableSoccer/42/media/anims_X/PS_PowerTackle.txt');
fs.mkdirSync(path.dirname(marker),{recursive:true});
fs.writeFileSync(marker,'# Discovery marker: native text payload is media/anims/ps_powertackle.txt\n');
// B42 loadHumanAnimations returns before version scanning if common/anims_X
// is absent. It scans every file (no extension filter), so use the same owned
// discovery key, not a .keep that would request a nonexistent animation.
const commonMarker=path.join(__dirname,'../Contents/mods/PlayableSoccer/common/media/anims_X/PS_PowerTackle.txt');
fs.mkdirSync(path.dirname(commonMarker),{recursive:true});
fs.writeFileSync(commonMarker,fs.readFileSync(marker));
console.log('Generated original 0.56s PowerTackle: 12 upper-body bones, 72 keys.');
if(process.argv.includes('--report')) {
 const rotate=(q,v)=>mul(mul(q,[...v,0]),[-q[0],-q[1],-q[2],q[3]]).slice(0,3);
 const dot=(a,b)=>a.reduce((s,v,i)=>s+v*b[i],0)/(Math.hypot(...a)*Math.hypot(...b));
 for(const w of [0,1]) {
  const world=[];for(let i=0;i<bones.length;i++){const q=i<2?bones[i].q:pose(bones[i],w);world.push(parents[i]<0?q:mul(world[parents[i]],q));}
  const up=rotate(world[3],[1,0,0]);
  for(const side of ['L','R']){const i=names.indexOf('Bip01_'+side+'_UpperArm'),f=i+1;
   console.log(JSON.stringify({phase:w,side,upperArmDotUp:dot(rotate(world[i],[1,0,0]),up),elbowBendDegrees:Math.acos(dot(rotate(world[i],[1,0,0]),rotate(world[f],[1,0,0])))*180/Math.PI}));}
 }
}
