import { createClient } from 'npm:@supabase/supabase-js@2.49.1';

const url = Deno.env.get('SUPABASE_URL')!;
const secret = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const admin = createClient(url, secret, { auth: { persistSession: false, autoRefreshToken: false } });
const site = 'https://ace-ship-it-ui.github.io/balamani/client.html';
const headers = { 'Access-Control-Allow-Origin': 'https://ace-ship-it-ui.github.io', 'Access-Control-Allow-Headers': 'authorization, apikey, content-type', 'Access-Control-Allow-Methods': 'POST, OPTIONS', 'Cache-Control': 'no-store', 'Content-Type': 'application/json' };
function reply(body: unknown, status = 200) { return new Response(JSON.stringify(body), { status, headers }); }
function checked(result: any) { if (result.error) throw new Error(result.error.message); return result.data; }
async function digest(value: string) { return Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(value))),b=>b.toString(16).padStart(2,'0')).join(''); }

Deno.serve(async (req) => {
 if (req.method === 'OPTIONS') return new Response(null, { headers });
 if (req.method !== 'POST') return reply({ error: 'POST required' }, 405);
 try {
  const bearer = (req.headers.get('authorization') || '').replace(/^Bearer /i, '');
  const body = await req.json();
  const action = body.action;
  if(action==='accept_invitation') {
   const code=String(body.code||'');
   if(!/^[0-9a-f]{64}$/.test(code)) return reply({error:'Invalid invitation. Ask an owner for a replacement.'},400);
   const member=checked(await admin.rpc('balamani_invitation_consume',{p_hash:await digest(code)}));
   if(!member) return reply({error:'This invitation has already been used or replaced. Ask an owner for a new one.'},400);
   // Mint the short-lived Auth credential only when the recipient accepts.
   const result=await admin.auth.admin.generateLink({type:'recovery',email:member.email,options:{redirectTo:site}});
   if(result.error || result.data.user.id!==member.id) return reply({error:'Unable to activate access. Ask an owner for a replacement invitation.'},400);
   return reply({token_hash:result.data.properties.hashed_token,type:'recovery'});
  }
  // Bootstrap is available solely to the project's server credential, never a browser key.
  const serverKeys = Object.values(JSON.parse(Deno.env.get('SUPABASE_SECRET_KEYS') || '{}'));
  const suppliedKey = req.headers.get('apikey') || '';
  const serverCredential = bearer === secret || (suppliedKey.startsWith('sb_secret_') && serverKeys.includes(suppliedKey));
  const bootstrap = serverCredential && action === 'bootstrap';
  if (!bootstrap && !bearer) return reply({error:'Please sign in'},401);
  let actor: any = null;
  if (!bootstrap) {
   const {data,error}=await admin.auth.getUser(bearer);
   if(error || !data.user) return reply({error:'Please sign in again'},401);
   actor=checked(await admin.rpc('balamani_actor',{p_id:data.user.id}));
   if(!actor) return reply({error:'Your account does not have client-area access. Contact Balamani.'},403);
  }
  if(action==='account_delete') {
   if(!actor.owner) return reply({error:'Owner access required'},403);
   const memberId=String(body.member_id||'');
   if(!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(memberId)) return reply({error:'Choose a client account'},400);
   const member=checked(await admin.from('balamani_members').select('id,email').eq('id',memberId).maybeSingle());
   if(!member) return reply({error:'Client account not found'},404);
   if(checked(await admin.rpc('balamani_is_owner_email',{p_email:member.email}))) return reply({error:'Owner accounts are protected'},403);
   if(String(body.confirm_email||'').trim().toLowerCase()!==member.email.toLowerCase()) return reply({error:'Type the client email to confirm permanent login removal'},400);
   // Revoke app access before removing Auth credentials. Preserve booking references.
   checked(await admin.rpc('balamani_viewing_change',{p_actor:actor.id,p_action:'view_create',p_data:{account_operation:'archive',member_id:member.id}}));
   const deletion=await admin.auth.admin.deleteUser(member.id,true);
   if(deletion.error) return reply({error:'Account archived, but permanent login removal failed. '+deletion.error.message},400);
   checked(await admin.from('balamani_audit').insert({actor_id:actor.id,action:'account_delete_login',target_id:member.id}));
   return reply({ok:true});
  }
  if(action==='state') {
   let query=admin.from('balamani_bookings').select('*').order('created_at',{ascending:false}).limit(500);
   if(!actor.owner) query=query.eq('member_id',actor.id);
   const bookings=checked(await query);
   const blocks=checked(await admin.from('balamani_blocked_dates').select('day').order('day'));
   const members=actor.owner?checked(await admin.from('balamani_members').select('id,email,full_name,dog_name,active').order('created_at',{ascending:false}).limit(500)):[];
   const occupancy=checked(await admin.rpc('balamani_occupancy'));
   const viewings=checked(await admin.rpc('balamani_viewing_state',{p_actor:actor.id}));
   return reply({actor,bookings,blocks:blocks.map((x:any)=>x.day),members,occupancy,viewings});
  }
  if(['invite','recovery','bootstrap'].includes(action)) {
   if(!bootstrap && !actor.owner) return reply({error:'Owner access required'},403);
   const email=String(body.email||'').trim().toLowerCase();
   if(email.length>254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return reply({error:'Enter a valid email address'},400);
   if(bootstrap && !checked(await admin.rpc('balamani_is_owner_email',{p_email:email}))) return reply({error:'Bootstrap is restricted to configured owners'},403);
   const existing=checked(await admin.from('balamani_members').select('id,active').eq('email',email).maybeSingle());
   if(existing && !existing.active) return reply({error:'This account is inactive'},403);
   if(action==='recovery' && !existing) return reply({error:'Invite this client first'},400);
   // Limit credential-link generation per owner; raw links are never stored.
   if(actor){const since=new Date(Date.now()-3600000).toISOString();const recent=await admin.from('balamani_audit').select('id',{count:'exact',head:true}).eq('actor_id',actor.id).eq('action','link').gte('created_at',since);if(recent.error)throw recent.error;if((recent.count||0)>=20)return reply({error:'Hourly invitation limit reached. Try later.'},429);}
   const type=existing?'recovery':'invite';
   const data=checked(await admin.auth.admin.generateLink({type,email,options:{redirectTo:site}}));
   if(!existing) checked(await admin.from('balamani_members').insert({id:data.user.id,email}));
   checked(await admin.from('balamani_audit').insert({actor_id:actor?.id||null,action:'link',target_id:data.user.id}));
   // Fragment avoids putting the credential into HTTP requests, referers, or Pages access logs.
   let link=site+'#token_hash='+encodeURIComponent(data.properties.hashed_token)+'&type='+type;
   if(action!=='recovery') {
    const code=Array.from(crypto.getRandomValues(new Uint8Array(32)),b=>b.toString(16).padStart(2,'0')).join('');
    checked(await admin.rpc('balamani_invitation_issue',{p_member:data.user.id,p_hash:await digest(code)}));
    link=site+'?v=durable-invites1#invite_code='+code;
   }
   return reply({link,email,type});
  }
  if(['view_create','view_close','view_request','view_decision','view_cancel'].includes(action)) {
   checked(await admin.rpc('balamani_viewing_change',{p_actor:actor.id,p_action:action,p_data:body}));
   return reply({ok:true});
  }
  if(['request','decision','cancel','block','profile'].includes(action)) {
   checked(await admin.rpc('balamani_change',{p_actor:actor.id,p_action:action,p_data:body}));
   return reply({ok:true});
  }
  return reply({error:'Unknown action'},400);
 } catch(error) {
  const message=error instanceof Error?error.message:'Request failed';
  // Return useful validation messages, without server credentials or request bodies.
  return reply({error:message.includes('duplicate key')?'These dates have already been requested.':message},400);
 }
});

