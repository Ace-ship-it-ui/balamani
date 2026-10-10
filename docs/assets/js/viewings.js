'use strict';
let viewingMonth=new Date(new Date().getFullYear(),new Date().getMonth(),1),viewingDay='';
function viewingData(){return state.viewings||{slots:[],requests:[]}}
function viewingTime(value){return String(value).slice(0,5)}
function viewingCalendar(){
 const slots=viewingData().slots;
 let cells=['Mon','Tue','Wed','Thu','Fri','Sat','Sun'].map(x=>'<span class="small">'+x+'</span>').join('');
 cells+='<span></span>'.repeat((viewingMonth.getDay()+6)%7);
 for(let i=1;i<=new Date(viewingMonth.getFullYear(),viewingMonth.getMonth()+1,0).getDate();i++){
  const day=dateKey(new Date(viewingMonth.getFullYear(),viewingMonth.getMonth(),i)),items=slots.filter(s=>s.day===day);
  const open=items.filter(s=>!s.closed&&!s.status&&!s.past).length,pending=items.filter(s=>s.status==='Pending').length,confirmed=items.filter(s=>s.status==='Confirmed').length;
  cells+=`<button type="button" class="day ${confirmed?'has-booking':pending?'has-request':''}" data-view-day="${day}" aria-pressed="${viewingDay===day}" aria-label="${day}: ${open} open viewing slots, ${pending} pending, ${confirmed} confirmed"><span>${i}</span><span class="small">${open?open+' open':items.length?'No openings':'—'}</span><span class="day-markers">${pending?`<span class="stay-marker pending">${pending} pending</span>`:''}${confirmed?`<span class="stay-marker confirmed">${confirmed} booked</span>`:''}</span></button>`;
 }
 return `<div class="row"><button type="button" data-view-month="-1" aria-label="Previous viewing month">←</button><strong>${viewingMonth.toLocaleDateString('en-GB',{month:'long',year:'numeric'})}</strong><button type="button" data-view-month="1" aria-label="Next viewing month">→</button></div><div class="calendar">${cells}</div><p class="small">Select a date to see appointment times. Amber: pending · Green: confirmed. All times are local to Malta.</p>`;
}
function viewingSlotList(){
 if(!viewingDay)return '<p>Select a date on the viewing calendar.</p>';
 const slots=viewingData().slots.filter(s=>s.day===viewingDay);
 return `<h3>${esc(viewingDay)}</h3>`+(slots.length?slots.map(s=>`<article class="booking"><div class="row"><strong>${viewingTime(s.starts)}–${viewingTime(s.ends)}</strong><span class="badge ${s.status||''}">${s.past?'Past':s.closed?'Closed':s.status||'Available'}</span></div>${state.actor.owner?`<p class="small">One family per appointment${s.closed&&s.status?' · Existing '+s.status.toLowerCase()+' request remains unchanged':''}.</p>${!s.past?`<button type="button" data-view-close="${s.id}" data-closed="${!s.closed}">${s.closed?'Reopen slot':'Close slot'}</button>`:''}`:!s.past&&!s.closed&&!s.status?`<button type="button" class="primary" data-view-request="${s.id}">Request this viewing</button>`:''}</article>`).join(''):'<p>No viewing appointments have been created for this date.</p>');
}
function viewingRequestList(){
 return viewingData().requests.length?viewingData().requests.map(r=>`<article class="booking"><div class="row"><strong>${esc(r.family_name)}</strong><span class="badge ${r.status}">${r.status}</span></div><p>${esc(r.day)} · ${viewingTime(r.starts)}–${viewingTime(r.ends)} (Malta)</p><div class="row">${state.actor.owner&&r.status==='Pending'?`${!r.past?`<button class="primary" data-view-decision="Confirmed" data-view-id="${r.id}">Approve viewing</button>`:''}<button data-view-decision="Declined" data-view-id="${r.id}">Decline viewing</button>`:''}${state.actor.owner&&['Pending','Confirmed'].includes(r.status)?`<button data-view-decision="Cancelled" data-view-id="${r.id}">Cancel viewing</button>`:!state.actor.owner&&r.status==='Pending'?`<button data-view-cancel="${r.id}">Withdraw viewing request</button>`:''}</div></article>`).join(''):'<p>No viewing requests yet.</p>';
}
function viewingShell(){
 return `<section id="puppy-viewings"><h2>Puppy viewings</h2><p>Meet the puppies by appointment. One family per slot, with owner approval. This calendar is separate from kennel bookings.</p><div class="split"><div><section class="card"><h3>Viewing calendar</h3><div id="viewing-calendar">${viewingCalendar()}</div></section><section class="card">${!state.actor.owner?`<label for="viewing-family">Your name / family name</label><input id="viewing-family" maxlength="100" value="${esc(state.actor.full_name)}"><p class="small">Your request holds the viewing slot while an owner reviews it.</p>`:''}<div id="viewing-slots">${viewingSlotList()}</div></section></div><div>${state.actor.owner?`<section class="card"><h3>Create a viewing slot</h3><form id="viewing-create"><label for="viewing-date">Date</label><input id="viewing-date" type="date" required><label for="viewing-start">Start time (Malta)</label><input id="viewing-start" type="time" required><label for="viewing-end">End time (Malta)</label><input id="viewing-end" type="time" required><button class="primary">Create viewing slot</button></form><p class="small">Create each appointment separately. Viewing times cannot overlap. Closing a slot stops new requests; use Cancel viewing to cancel an existing appointment.</p></section>`:''}<section class="card"><h3>${state.actor.owner?'Viewing requests & appointments':'Your viewing requests'}</h3><div id="viewing-requests">${viewingRequestList()}</div></section></div></div></section>`;
}
function refreshViewings(){if(!$('viewing-calendar'))return;$('viewing-calendar').innerHTML=viewingCalendar();$('viewing-slots').innerHTML=viewingSlotList();$('viewing-requests').innerHTML=viewingRequestList();bindViewingControls()}
function bindViewingControls(){
 document.querySelectorAll('[data-view-month]').forEach(b=>b.onclick=()=>{viewingMonth.setMonth(viewingMonth.getMonth()+Number(b.dataset.viewMonth));refreshViewings()});
 document.querySelectorAll('[data-view-day]').forEach(b=>b.onclick=()=>{viewingDay=b.dataset.viewDay;if($('viewing-date'))$('viewing-date').value=viewingDay;refreshViewings()});
 document.querySelectorAll('[data-view-request]').forEach(b=>b.onclick=()=>run(b,async()=>{const family=$('viewing-family').value.trim();if(!family)throw new Error('Enter your name for the viewing.');await api('view_request',{slot_id:b.dataset.viewRequest,family_name:family});await refresh(false);message('Viewing requested. An owner will review your appointment.')}));
 document.querySelectorAll('[data-view-close]').forEach(b=>b.onclick=()=>run(b,async()=>{await api('view_close',{id:b.dataset.viewClose,closed:b.dataset.closed==='true'});await refresh(false);message('Viewing slot updated.')}));
 document.querySelectorAll('[data-view-decision]').forEach(b=>b.onclick=()=>{if(!confirm(b.dataset.viewDecision+' this viewing?'))return;run(b,async()=>{await api('view_decision',{id:b.dataset.viewId,status:b.dataset.viewDecision});await refresh(false);message('Viewing appointment updated.')})});
 document.querySelectorAll('[data-view-cancel]').forEach(b=>b.onclick=()=>run(b,async()=>{await api('view_cancel',{id:b.dataset.viewCancel});await refresh(false);message('Viewing request withdrawn.')}));
}
function bindViewings(){
 bindViewingControls();
 if($('viewing-create'))$('viewing-create').onsubmit=e=>{e.preventDefault();run(e.submitter,async()=>{const day=$('viewing-date').value;await api('view_create',{day,starts:$('viewing-start').value,ends:$('viewing-end').value});viewingDay=day;const parts=day.split('-').map(Number);viewingMonth=new Date(parts[0],parts[1]-1,1);await refresh(false);message('Viewing appointment time created.')})};
}
