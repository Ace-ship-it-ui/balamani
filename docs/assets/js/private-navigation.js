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
 <h2>Play with Aizen</h2><div class="pet-scene"><svg viewBox="0 0 220 145" role="img" aria-label="Animated fawn and white Shih Tzu Aizen">
 <defs>
 <radialGradient id="aizen-fawn" cx=".38" cy=".25" r=".8"><stop stop-color="#eedbc0"/><stop offset=".55" stop-color="#c4a17c"/><stop offset="1" stop-color="#967153"/></radialGradient>
 <radialGradient id="aizen-white" cx=".4" cy=".2" r=".9"><stop stop-color="#fffef7"/><stop offset=".65" stop-color="#eee5d7"/><stop offset="1" stop-color="#c6b49c"/></radialGradient>
 <linearGradient id="aizen-ear" x2=".8" y2="1"><stop stop-color="#bc9876"/><stop offset=".6" stop-color="#927257"/><stop offset="1" stop-color="#5d493b"/></linearGradient>
 <radialGradient id="aizen-eye"><stop stop-color="#6b4931"/><stop offset=".55" stop-color="#35271f"/><stop offset="1" stop-color="#100e0d"/></radialGradient>
 </defs>
 <ellipse cx="105" cy="124" rx="60" ry="4" fill="#493726" opacity=".16"/><g class="aizen-dog">
 <path class="aizen-tail" d="M140 83 Q178 43 157 47 Q142 48 151 62" fill="none" stroke="#fff8eb" stroke-width="17" stroke-linecap="round"/>
 <ellipse cx="112" cy="91" rx="43" ry="25" fill="url(#aizen-fawn)"/><ellipse cx="112" cy="97" rx="29" ry="18" fill="url(#aizen-white)"/><ellipse class="aizen-belly" cx="112" cy="97" rx="23" ry="14" fill="#edc5b6"/>
 <path d="M100 72 Q109 83 107 103 M117 71 Q125 83 123 108 M134 79 Q143 89 142 99" stroke="#f1e1c9" stroke-width="1.3" opacity=".65" fill="none"/>
 <g class="aizen-leg" fill="url(#aizen-white)"><path d="M80 99 Q75 106 78 119 Q73 126 83 127 L96 126 Q101 122 93 119 L94 103Z"/><path d="M130 99 Q127 110 130 119 Q125 126 135 127 L148 126 Q152 121 144 119 L145 103Z"/></g>
 <g class="aizen-head"><path d="M51 37 Q30 36 33 65 L35 83 L40 89 L44 84 L48 89 Q58 76 59 54Z" fill="url(#aizen-ear)"/><path d="M96 37 Q115 38 112 66 L109 85 L103 90 L99 85 L95 89 Q86 71 88 51Z" fill="url(#aizen-ear)"/>
 <path d="M42 50 Q40 30 59 27 L64 23 L68 26 L74 21 L80 26 L86 24 Q108 29 105 55 L101 75 Q75 91 45 75Z" fill="url(#aizen-fawn)"/>
 <path d="M66 28 Q72 34 67 49 L61 62 L73 78 L86 62 L79 48 Q74 36 81 27" fill="url(#aizen-white)"/>
 <g fill="none" stroke="#f4e2c7" stroke-width="1.1" opacity=".85"><path d="M48 39 Q53 31 64 31 M45 44 Q53 36 62 35 M84 32 Q97 34 102 42 M86 36 Q98 39 102 46 M69 29 L72 42 M76 27 L75 40"/><path d="M38 51 L39 76 M42 46 L44 81 M47 45 L48 75 M105 48 L104 79 M100 46 L99 77"/></g>
 <g class="aizen-eye" fill="url(#aizen-eye)" stroke="#5c4434" stroke-width="1"><ellipse cx="60" cy="52" rx="7.5" ry="8"/><ellipse cx="88" cy="52" rx="7.5" ry="8"/></g>
 <g fill="#fff"><circle cx="58" cy="49.5" r="2.3"/><circle cx="86" cy="49.5" r="2.3"/><circle cx="63" cy="55" r=".8"/><circle cx="91" cy="55" r=".8"/></g>
 <path d="M51 59 Q63 53 74 61 Q85 53 97 60 L99 73 L94 78 L89 77 L86 83 L78 81 L74 85 L68 81 L61 83 L57 78 L50 79 L47 69Z" fill="url(#aizen-white)"/>
 <path d="M68 77 Q74 82 80 77 L77 86 Q73 89 70 85Z" fill="#bd777b"/><path d="M74 78 L74 85" stroke="#8f5356" stroke-width=".7"/>
 <path d="M66 62 Q74 56 82 62 Q82 69 74 70 Q67 68 66 62" fill="#201c1b"/><ellipse cx="72" cy="61" rx="3.5" ry="1.2" fill="#77716d"/><path d="M74 69 L74 74 M67 74 Q74 78 81 74" stroke="#665347" stroke-width=".8" fill="none"/>
 <g stroke="#bbaa95" stroke-width=".65" fill="none"><path d="M59 65 L51 72 M63 65 L55 77 M67 69 L63 80 M88 65 L95 72 M84 67 L91 78 M80 70 L84 81 M69 78 L68 83 M79 78 L80 83"/></g>
 </g></g>
 <g class="aizen-ball"><circle cx="112" cy="117" r="8" fill="#b3cb55"/><path d="M107 111 Q116 117 107 123" fill="none" stroke="#fff" stroke-width="2"/></g></svg><span class="pet-effect" aria-hidden="true"></span></div>
 <p>Make a happy pup: try all three!</p><progress max="100" value="0" aria-label="Aizen happiness"></progress>
 <p class="pet-status" role="status">Aizen is ready to play. 0/3</p>
 <div class="pet-actions"><button type="button" data-action="treat">Give a treat</button><button type="button" data-action="rub">Belly rub</button><button type="button" data-action="play">Play fetch</button></div>
 </div>
 <button class="pet-open" type="button" hidden>Wake Aizen</button>`;
 document.body.appendChild(pet);
 const freeStyle=document.createElement('style');
 freeStyle.textContent=`
 #balamani-companion{width:160px;padding:0;border:0;border-radius:0;background:transparent;box-shadow:none;pointer-events:none}
 #balamani-companion .pet-scene{background:transparent;border:0;border-radius:0;overflow:visible;cursor:pointer;pointer-events:auto}
 #balamani-companion svg{height:112px;overflow:visible}
 #balamani-companion .pet-scene:focus-visible{outline:2px solid #927447;border-radius:12px}
 #balamani-companion .pet-content>h2,#balamani-companion .pet-content>p,#balamani-companion progress,#balamani-companion .pet-actions,#balamani-companion .pet-close{display:none}
 #balamani-companion.menu-open .pet-actions{display:grid;position:absolute;bottom:115px;right:0;width:190px;padding:10px;background:#fffdf8;border:1px solid #d8c197;border-radius:15px;box-shadow:0 4px 18px #34271c22;pointer-events:auto}
 #balamani-companion.menu-open .pet-close{display:block;position:absolute;right:0;top:auto;bottom:245px;background:#fffdf8;border:1px solid #d8c197;border-radius:10px;pointer-events:auto;font-size:12px;padding:6px 10px}
 #balamani-companion .pet-open{pointer-events:auto}
 #balamani-companion.pet-hidden{width:auto;padding:0}
 #balamani-companion.running{animation:across-screen 4s ease-in-out}
 #balamani-companion .action-play .aizen-dog{animation:none}
 #balamani-companion .action-play .aizen-ball{animation:leading-ball 4s linear}
 @keyframes across-screen{0%,100%{transform:translateX(0)}40%,55%{transform:translateX(calc(-100vw + 185px))}}
 @keyframes leading-ball{0%,95%{opacity:1;transform:translateX(-70px)}100%{opacity:0}}
 @media(max-width:480px){#balamani-companion{width:135px;padding:0}#balamani-companion svg{height:100px}}
 @media(prefers-reduced-motion:reduce){#balamani-companion.running{animation:none}}
 `;document.head.appendChild(freeStyle);
 const scene=pet.querySelector('.pet-scene');
 scene.setAttribute('role','button');scene.setAttribute('tabindex','0');scene.setAttribute('aria-label','Aizen: open activities');scene.setAttribute('aria-expanded','false');
 function toggleMenu(){const shown=pet.classList.toggle('menu-open');scene.setAttribute('aria-expanded',String(shown))}
 scene.addEventListener('click',toggleMenu);
 scene.addEventListener('keydown',event=>{if(event.key==='Enter'||event.key===' '){event.preventDefault();toggleMenu()}if(event.key==='Escape'){pet.classList.remove('menu-open');scene.setAttribute('aria-expanded','false')}});
 const open=pet.querySelector('.pet-open'),status=pet.querySelector('.pet-status'),meter=pet.querySelector('progress'),image=pet.querySelector('svg'),effect=pet.querySelector('.pet-effect');
 const seen=new Set();let timer;
 const replies={treat:['A tasty virtual treat!','🦴'],rub:['Aizen loves his belly rub!','💕'],play:['Good catch, Aizen!','🎾']};
 function hide(){pet.classList.remove('menu-open','running');scene.setAttribute('aria-expanded','false');pet.classList.add('pet-hidden');open.hidden=false;try{sessionStorage.setItem('balamani-pet-hidden','1')}catch{}}
 pet.querySelector('.pet-close').addEventListener('click',()=>{hide();open.focus()});
 open.addEventListener('click',()=>{pet.classList.remove('pet-hidden');open.hidden=true;try{sessionStorage.removeItem('balamani-pet-hidden')}catch{}scene.focus()});
 pet.querySelectorAll('[data-action]').forEach(button=>button.addEventListener('click',()=>{
 const action=button.dataset.action;seen.add(action);meter.value=Math.round(seen.size/3*100);
 status.textContent=seen.size===3?'Happy pup! You are Aizen’s new friend. 3/3':replies[action][0]+' '+seen.size+'/3';
 clearTimeout(timer);pet.classList.remove('menu-open','running');scene.setAttribute('aria-expanded','false');scene.focus();image.classList.remove('action-play','action-rub','action-treat');void image.getBoundingClientRect();image.classList.add('action-'+action);if(action==='play')pet.classList.add('running');effect.textContent=action==='rub'?'💕':action==='treat'?'🦴':'';
 timer=setTimeout(()=>{effect.textContent='';pet.classList.remove('running');image.classList.remove('action-play','action-rub','action-treat')},action==='play'?4100:3100);
 }));
 try{if(sessionStorage.getItem('balamani-pet-hidden')==='1')hide()}catch{}
})();





