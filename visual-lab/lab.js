'use strict';

const canvas = document.getElementById('nocturne');
const ctx = canvas.getContext('2d', { alpha: false });
const W = canvas.width, H = canvas.height;
const qs = new URLSearchParams(window.__CAPTURE_QUERY__ || location.search);
let screen = qs.get('screen') || 'gameplay';
let pass = Math.max(1, Math.min(3, +(qs.get('pass') || 3)));
const capture = qs.get('capture') === '1';
let reduced = qs.get('reduced') === '1';
const STATIC_T = +(qs.get('t') || 18.4);
if (capture) document.body.classList.add('capture');

const P = {
  void:'#050408', coal:'#0a0810', ink:'#e7dfe2', dim:'#9a8990', faint:'#5f5058',
  blood:'#b4213b', blood2:'#ef355e', oxblood:'#571322', arterial:'#ff426d',
  bone:'#d8c4ad', brass:'#bd9462', amber:'#f0b56c', sodium:'#ffd79a',
  cyan:'#62d8d0', teal:'#1c827f', violet:'#9168d8', blue:'#5f8ccc',
  green:'#65976f', road:'#15151c', pavement:'#29272f', wall:'#25202a',
  roof:'#15121a', fog:'#73808c', white:'#f6f0ed'
};

const state = { mouseX:0, mouseY:0, hover:-1 };
const TAU = Math.PI * 2;
const clamp = (v,a,b)=>Math.max(a,Math.min(b,v));
const lerp = (a,b,t)=>a+(b-a)*t;
const rgba = (hex,a=1) => {
  let s=hex.replace('#',''); if(s.length===3)s=s.split('').map(x=>x+x).join('');
  const n=parseInt(s,16); return `rgba(${n>>16},${(n>>8)&255},${n&255},${a})`;
};
const shade=(hex,f)=>{
  let s=hex.replace('#',''); if(s.length===3)s=s.split('').map(x=>x+x).join('');
  let n=parseInt(s,16), r=n>>16,g=(n>>8)&255,b=n&255;
  const t=f<0?0:255,p=Math.abs(f); r=Math.round((t-r)*p+r);g=Math.round((t-g)*p+g);b=Math.round((t-b)*p+b);
  return `rgb(${r},${g},${b})`;
};
function rng(seed){ let a=seed>>>0; return ()=>{ a+=0x6D2B79F5; let t=a; t=Math.imul(t^t>>>15,t|1);t^=t+Math.imul(t^t>>>7,t|61);return ((t^t>>>14)>>>0)/4294967296; }; }
const R=rng(0xC0FFEE);

function rr(x,y,w,h,r=8){
  r=Math.min(r,w/2,h/2);ctx.beginPath();ctx.