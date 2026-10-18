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
 #balamani-companion{position:fixed;right:16px;bottom:16px;z-index:50;width:142px;padding:10px;border:1px solid #d8c197;border-radius:20px;background:#fffdf8;box-shadow:0 5px 22px #34271c24;text-align:center;font:13px/1.4 system-ui,sans-serif;color:#352b25}
 #balamani-companion button{cursor:pointer;font:inherit;border:1px solid #d8c197;border-radius:12px;background:#f7efe1;color:#352b25;padding:5px 10px}
 #balamani-companion .pet-close{position:absolute;right:5px;top:3px;border:0;background:transparent;font-size:18px;padding:0 5px}
 #balamani-companion svg{display:block;width:110px;height:100px;margin:4px auto;overflow:visible}
 #balamani-companion .pet-tail{transform-origin:100px 66px;animation:pet-wag .65s ease-in-out infinite alternate}
 #balamani-companion .pet-dog{transform-origin:60px 90px}
 #balamani-companion .pet-playing{animation:pet-hop .5s ease-in-out 4}
 #balamani-companion .pet-status{min-height:19px;margin:2px 0 6px}
 #balamani-companion.pet-hidden{width:auto;padding:6px}
 #balamani-companion.pet-hidden .pet-content,#balamani-companion.pet-hidden .pet-close{display:none}
 @keyframes pet-wag{to{transform:rotate(24deg)}}
 @keyframes pet-hop{50%{transform:translateY(-10px) rotate(-5deg)}}
 @media(prefers-reduced-motion:reduce){#balamani-companion *{animation:none!important}}
 @media(max-width:480px){#balamani-companion{right:10px;bottom:10px;width:116px;padding:8px}#balamani-companion svg{width:90px;height:82px}}
 `;
 document.head.appendChild(style);
 const pet=document.createElement('aside');pet.id='balamani-companion';pet.setAttribute('aria-label','Playful Shih Tzu companion');
 pet.innerHTML=`<button class="pet-close" type="button" aria-label="Hide Shih Tzu companion">&times;</button>
 <div class="pet-content"><svg viewBox="0 0 120 105" role="img" aria-label="A playful cream and white Shih Tzu">
 <ellipse cx="60" cy="97" rx="38" ry="5" fill="#eadfce"/>
 <g class="pet-dog"><path class="pet-tail" d="M90 76 Q118 41 100 39 Q88 38 98 54" fill="none" stroke="#d6b48d" stroke-width="13" stroke-linecap="round"/>
 <ellipse cx="65" cy="77" rx="31" ry="20" fill="#f1e7d7"/><ellipse cx="46" cy="92" rx="12" ry="7" fill="#fffdf8"/><ellipse cx="80" cy="92" rx="12" ry="7" fill="#fffdf8"/>
 <ellipse cx="31" cy="49" rx="16" ry="28" fill="#a78061"/><ellipse cx="88" cy="49" rx="16" ry="28" fill="#a78061"/>
 <path d="M27 42 Q24 13 48 13 L59 5 L69 14 Q96 10 94 44 L91 66 Q60 87 29 65Z" fill="#e0c5a4"/>
 <path d="M49 16 Q58 26 54 45 L41 60 L61 75 L81 60 L66 45 Q62 25 69 15" fill="#fffdf8"/>
 <ellipse cx="44" cy="45" rx="8" ry="10" fill="#30251f"/><ellipse cx="77" cy="45" rx="8" ry="10" fill="#30251f"/>
 <circle cx="42" cy="42" r="2.5" fill="white"/><circle cx="75" cy="42" r="2.5" fill="white"/>
 <ellipse cx="49" cy="60" rx="16" ry="12" fill="#fffdf8"/><ellipse cx="72" cy="60" rx="16" ry="12" fill="#fffdf8"/>
 <path d="M54 55 Q61 50 68 55 Q67 63 61 63 Q55 62 54 55" fill="#30251f"/>
 <path d="M56 69 Q61 74 67 69 L65 79 Q60 84 57 78Z" fill="#e5a2a3"/></g></svg>
 <p class="pet-status" aria-live="polite">Hello, friend!</p><button class="pet-play" type="button">Play with me</button></div>
 <button class="pet-open" type="button" hidden aria-label="Show Shih Tzu companion">Meet our pup</button>`;
 document.body.appendChild(pet);
 const dog=pet.querySelector('.pet-dog'),status=pet.querySelector('.pet-status'),open=pet.querySelector('.pet-open');
 function hide(){pet.classList.add('pet-hidden');open.hidden=false;try{sessionStorage.setItem('balamani-pet-hidden','1')}catch{}}
 pet.querySelector('.pet-close').addEventListener('click',()=>{hide();open.focus()});
 open.addEventListener('click',()=>{pet.classList.remove('pet-hidden');open.hidden=true;try{sessionStorage.removeItem('balamani-pet-hidden')}catch{}pet.querySelector('.pet-play').focus()});
 let turn=0,timer;
 pet.querySelector('.pet-play').addEventListener('click',()=>{clearTimeout(timer);dog.classList.remove('pet-playing');void dog.getBoundingClientRect();dog.classList.add('pet-playing');status.textContent=['Happy tail wags!','Belly rubs, please!','You made my day!'][turn++%3];timer=setTimeout(()=>dog.classList.remove('pet-playing'),2100)});
 try{if(sessionStorage.getItem('balamani-pet-hidden')==='1')hide()}catch{}
})();
