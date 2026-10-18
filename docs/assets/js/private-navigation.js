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
 #balamani-companion .pet-close{position:absolute;right:7px;top:3px;border:0;background:transparent;font-size:21px;padding:0 5px;z-index:2}
 #balamani-companion h2{font:700 17px system-ui;margin:2px 16px 8px;border:0;padding:0}
 #balamani-companion .pet-scene{position:relative;overflow:hidden;border-radius:14px;background:#e9dfd0}
 #balamani-companion img{display:block;width:100%;height:135px;object-fit:cover;object-position:center 36%;margin:0;border-radius:0}
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
 pet.innerHTML=`<button class="pet-close" type="button" aria-label="Hide Aizen game">&times;</button><div class="pet-content">
 <h2>Play with Aizen</h2><div class="pet-scene"><img src="assets/images/aizen-fawn-white.png" alt="Aizen, our fawn and white Shih Tzu"><span class="pet-effect" aria-hidden="true"></span></div>
 <p>Make a happy pup: try all three!</p><progress max="100" value="0" aria-label="Aizen happiness"></progress>
 <p class="pet-status" role="status">Aizen is ready to play. 0/3</p>
 <div class="pet-actions"><button type="button" data-action="treat">Give a treat</button><button type="button" data-action="rub">Belly rub</button><button type="button" data-action="play">Play fetch</button></div>
 <button class="pet-again" type="button" hidden style="margin-top:6px">Play again</button></div>
 <button class="pet-open" type="button" hidden>Play with Aizen</button>`;
 document.body.appendChild(pet);
 const open=pet.querySelector('.pet-open'),status=pet.querySelector('.pet-status'),meter=pet.querySelector('progress'),again=pet.querySelector('.pet-again'),image=pet.querySelector('img'),effect=pet.querySelector('.pet-effect');
 const seen=new Set();let timer;
 const replies={treat:['A tasty virtual treat!','🦴'],rub:['Aizen loves his belly rub!','💕'],play:['Good catch, Aizen!','🎾']};
 function hide(){pet.classList.add('pet-hidden');open.hidden=false;try{sessionStorage.setItem('balamani-pet-hidden','1')}catch{}}
 pet.querySelector('.pet-close').addEventListener('click',()=>{hide();open.focus()});
 open.addEventListener('click',()=>{pet.classList.remove('pet-hidden');open.hidden=true;try{sessionStorage.removeItem('balamani-pet-hidden')}catch{}pet.querySelector('[data-action]').focus()});
 pet.querySelectorAll('[data-action]').forEach(button=>button.addEventListener('click',()=>{
 const action=button.dataset.action;seen.add(action);meter.value=Math.round(seen.size/3*100);
 status.textContent=seen.size===3?'Happy pup! You are Aizen’s new friend. 3/3':replies[action][0]+' '+seen.size+'/3';
 again.hidden=seen.size!==3;clearTimeout(timer);image.classList.remove('pet-react');void image.getBoundingClientRect();image.classList.add('pet-react');effect.textContent=replies[action][1];
 timer=setTimeout(()=>{effect.textContent='';image.classList.remove('pet-react')},1100);
 }));
 again.addEventListener('click',()=>{seen.clear();meter.value=0;again.hidden=true;status.textContent='Aizen is ready to play. 0/3';pet.querySelector('[data-action]').focus()});
 try{if(sessionStorage.getItem('balamani-pet-hidden')==='1')hide()}catch{}
})();



