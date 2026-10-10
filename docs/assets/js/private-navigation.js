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

