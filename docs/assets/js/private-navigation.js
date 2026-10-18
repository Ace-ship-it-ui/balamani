'use strict';
// This only controls navigation visibility. The client API enforces membership.
function showClientNavigation(){
 let invited=false;
 try{invited=localStorage.getItem('balamani-invited')==='1'||!!sessionStorage.getItem('balamani-session')}catch{}
 const nav=document.querySelector('nav[aria-label="Main navigation"]');
 if(!nav)return;
 let link=nav.querySelector('[data-client-area]');
 if(invited&&!link){link=document.createElement('a');link.href='client.html';link.textContent='Client area';link.setAttribute('data-client-area','');nav.appendChild(link)}
 else if(!invited&&link)link.remove();
}
showClientNavigation();
window.addEventListener('pageshow',showClientNavigation);
window.addEventListener('storage',showClientNavigation);

(function(){
 if(document.getElementById('balamani-companion'))return;
 const style=document.createElement('style');
 style.textContent=`
 #balamani-companion{position:fixed;right:14px;bottom:14px;z-index:50;width:218px;box-sizing:border-box;padding:12px;border:1px solid #d8c197;border-radius:20px;background:#fffdf8;box-shadow:0 6px 25px #34271c28;color:#352b25;font:13px/1.4 system-ui,sans-serif;text-align:center}
 #balamani-companion [hidden]{display:none!important}
 #balamani-companion button{cursor:pointer;font:inherit;border:1px solid #d8c197;border-radius:12px;background:#f7efe1;color:#352b25;padding:7px}
 #balamani-companion button:focus-visible{outline:3px solid #75603c;outline-offset:2px}
 #balamani-companion .pet-close{position:absolute;right:7px;top:3px;border:0;background:transparent;font-size:11px;padding:2px 5px;z-index:2}
 #balamani-companion h2{font:700 17px system-ui;margin:24px 0 8px;border:0;padding:0}
 #balamani-companion .pet-scene{position:relative;overflow:hidden;border-radius:14px;background:#e9dfd0}
 #balamani-companion svg{display:block;width:100%;height:135px}
 #balamani-companion .aizen-tail{transform-origin:143px 78px;animation:wag .5s ease-in-out infinite alternate}
 #balamani-companion .aizen-head{transform-origin:73px 72px;animation:look 4s ease-in-out infinite}
 #balamani-companion .aizen-eye{transform-origin:63px 49px;animation:blink 5s infinite}
 #balamani-companion .aizen-dog{transform-origin:100px 92px}
 #balamani-companion .aizen-ball{opacity:0}
 #balamani-companion .aizen-belly{display:none}
 #balamani-companion .action-play .aizen-dog{animation:chase 3s ease-in-out}
 #balamani-companion .action-play .aizen-leg{transform-box:fill-box;transform-origin:top;animation:run .18s infinite alternate}
 #balamani-companion .action-play .aizen-ball{animation:ball 3s ease-in-out}
 #balamani-companion .action-rub .aizen-dog{animation:rollover 3s ease-in-out}
 #balamani-companion .action-rub .aizen-belly{display:block}
 #balamani-companion .action-treat .aizen-head{animation:munch .3s ease-in-out 8}
 @keyframes wag{to{transform:rotate(28deg)}}
 @keyframes look{50%{transform:rotate(-7deg)}}
 @keyframes blink{0%,43%,47%,100%{transform:scaleY(1)}45%{transform:scaleY(.1)}}
 @keyframes run{to{transform:rotate(35deg)}}
 @keyframes chase{0%{transform:translateX(0) scale(.85)}40%{transform:translateX(75px) scale(.65)}55%{transform:translateX(75px) scale(-.65,.65)}90%{transform:translateX(-25px) scale(-.85,.85)}100%{transform:translateX(0) scale(.85)}}
 @keyframes ball{0%{opacity:1;transform:translate(-55px,-35px)}40%,60%{opacity:1;transform:translate(70px,0)}90%{opacity:1;transform:translate(-25px,0)}100%{opacity:0}}
 @keyframes rollover{0%,100%{transform:rotate(0)}20%,80%{transform:translateY(-22px) rotate(180deg)}}
 @keyframes munch{50%{transform:rotate(8deg) translateY(3px)}}
 #balamani-companion .pet-effect{position:absolute;inset:0;display:grid;place-items:center;font-size:38px;pointer-events:none}
 #balamani-companion .pet-react{animation:aizen-bounce .6s ease-in-out}
 #balamani-companion .pet-effect:not(:empty){animation:aizen-hearts .8s ease-out}
 #balamani-companion p{margin:6px 0;font-size:12px;line-height:1.4}
 #balamani-companion .pet-status{min-height:34px}
 #balamani-companion .pet-actions{display:grid;grid-template-columns:1fr 1fr;gap:6px}
 #balamani-companion .pet-actions button:last-child{grid-column:1/-1}
 #balamani-companion progress{display:block;width:100%;height:10px;accent-color:#927447}
 #balamani-companion.pet-hidden{width:auto;padding:6px}
 #balamani-companion.pet-hidden .pet-content,#balamani-companion.pet-hidden .pet-close{display:none}
 @keyframes aizen-bounce{50%{transform:translateY(-5px) rotate(-2deg)}}
 @keyframes aizen-hearts{from{opacity:0;transform:translateY(20px)}to{opacity:1;transform:translateY(-10px)}}
 @media(prefers-reduced-motion:reduce){#balamani-companion *{animation:none!important}}
 @media(max-width:480px){#balamani-companion{width:184px;right:8px;bottom:8px;padding:9px}#balamani-companion img{height:100px}}
 `;document.head.appendChild(style);
 const pet=document.createElement('aside');pet.id='balamani-companion';pet.setAttribute('aria-label','Play with Aizen');
 pet.innerHTML=`<button class="pet-close" type="button" aria-label="Go to bed">Go to bed</button><div class="pet-content">
 <h2>Play with Aizen</h2><div class="pet-scene"><svg viewBox="0 0 220 145" role="img" aria-label="Animated fawn and white Shih Tzu Aizen"><ellipse cx="105" cy="124" rx="70" ry="7" fill="#d4c7b2"/><g class="aizen-dog">
 <path class="aizen-tail" d="M140 83 Q178 43 157 47 Q142 48 151 62" fill="none" stroke="#fff8eb" stroke-width="17" stroke-linecap="round"/>
 <ellipse cx="112" cy="91" rx="43" ry="25" fill="#c6a078"/><ellipse cx="112" cy="97" rx="29" ry="18" fill="#fff8eb"/><ellipse class="aizen-belly" cx="112" cy="97" rx="23" ry="14" fill="#edc5b6"/>
 <g class="aizen-leg" fill="#fff8eb"><rect x="78" y="99" width="16" height="25" rx="7"/><rect x="128" y="99" width="16" height="25" rx="7"/></g>
 <g class="aizen-head"><ellipse cx="49" cy="65" rx="15" ry="28" fill="#9f7857"/><ellipse cx="98" cy="65" rx="15" ry="28" fill="#9f7857"/>
 <path d="M43 51 Q39 24 63 27 L73 19 L81 27 Q109 25 105 55 L100 78 Q74 96 45 78Z" fill="#d4b48d"/><path d="M67 29 L78 28 L81 55 L91 71 L73 83 L56 71 L69 54Z" fill="#fff8eb"/>
 <g class="aizen-eye" fill="#281f1a"><ellipse cx="60" cy="52" rx="7" ry="8"/><ellipse cx="88" cy="52" rx="7" ry="8"/></g><g fill="white"><circle cx="58" cy="50" r="2"/><circle cx="86" cy="50" r="2"/></g>
 <ellipse cx="63" cy="69" rx="16" ry="12" fill="#fff8eb"/><ellipse cx="84" cy="69" rx="16" ry="12" fill="#fff8eb"/><ellipse cx="74" cy="63" rx="8" ry="6" fill="#281f1a"/><path d="M68 77 Q74 82 80 77 L77 87 Q73 91 70 86Z" fill="#df9498"/>
 <path d="M46 43 L40 49 M45 60 L38 65 M99 40 L108 46 M103 60 L111 65" stroke="#e8d2b3" stroke-width="4" stroke-linecap="round"/></g></g>
 <g class="aizen-ball"><circle cx="112" cy="117" r="8" fill="#b3cb55"/><path d="M107 111 Q116 117 107 123" fill="none" stroke="#fff" stroke-width="2"/></g></svg><span class="pet-effect" aria-hidden="true"></span></div>
 <p>Make a happy pup: try all three!</p><progress max="100" value="0" aria-label="Aizen happiness"></progress>
 <p class="pet-status" role="status">Aizen is ready to play. 0/3</p>
 <div class="pet-actions"><button type="button" data-action="treat">Give a treat</button><button type="button" data-action="rub">Belly rub</button><button type="button" data-action="play">Play fetch</button></div>
 </div>
 <button class="pet-open" type="button" hidden>Wake Aizen</button>`;
 document.body.appendChild(pet);
 const open=pet.querySelector('.pet-open'),status=pet.querySelector('.pet-status'),meter=pet.querySelector('progress'),image=pet.querySelector('svg'),effect=pet.querySelector('.pet-effect');
 const seen=new Set();let timer;
 const replies={treat:['A tasty virtual treat!','🦴'],rub:['Aizen loves his belly rub!','💕'],play:['Good catch, Aizen!','🎾']};
 function hide(){pet.classList.add('pet-hidden');open.hidden=false;try{sessionStorage.setItem('balamani-pet-hidden','1')}catch{}}
 pet.querySelector('.pet-close').addEventListener('click',()=>{hide();open.focus()});
 open.addEventListener('click',()=>{pet.classList.remove('pet-hidden');open.hidden=true;try{sessionStorage.removeItem('balamani-pet-hidden')}catch{}pet.querySelector('[data-action]').focus()});
 pet.querySelectorAll('[data-action]').forEach(button=>button.addEventListener('click',()=>{
 const action=button.dataset.action;seen.add(action);meter.value=Math.round(seen.size/3*100);
 status.textContent=seen.size===3?'Happy pup! You are Aizen’s new friend. 3/3':replies[action][0]+' '+seen.size+'/3';
 clearTimeout(timer);image.classList.remove('action-play','action-rub','action-treat');void image.getBoundingClientRect();image.classList.add('action-'+action);effect.textContent=action==='rub'?'💕':action==='treat'?'🦴':'';
 timer=setTimeout(()=>{effect.textContent='';image.classList.remove('action-play','action-rub','action-treat')},3100);
 }));
 try{if(sessionStorage.getItem('balamani-pet-hidden')==='1')hide()}catch{}
})();





