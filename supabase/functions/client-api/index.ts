import { createClient } from 'npm:@supabase/supabase-js@2.49.1';

const url = Deno.env.get('SUPABASE_URL')!;
const secret = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const admin = createClient(url, secret, { auth: { persistSession: false, autoRefreshToken: false } });
const site = 'https://ace-ship-it-ui.github.io/balamani/client.html';
const headers = { 'Access-Control-Allow-Origin': 'https://ace-ship-it-ui.github.io', 'Access-Control-Allow-Headers': 'authorization, apikey, content-type', 'Access-Control-Allow-Methods': 'POST, OPTIONS', 'Cache-Control': 'no-store', 'Content-Type': 'application/json' };
function reply(body: unknown, status = 200) { return new Response(JSON.stringify(body), { status, headers }); }
function checked(result: any) { if (result.error) throw new Error(result.error.message); return result.data; }

Deno.serve(async (req) => {
 if (req.method === 'OPTIONS') return new Response(null, { headers });
 if (req.method !== 'POST') return reply({ error: 'POST required' }, 405);
 try {
  const bearer = (req.headers.get('authorization') || '').replace(/^Bearer /i, '');
  const body = await req.json();
  const action = body.action;
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
  if(action==='state') {
   let query=admin.from('balamani_bookings').select('*').order('created_at',{ascending:false}).limit(500);
   if(!actor.owner) query=query.eq('member_id',actor.id);
   const bookings=checked(await query);
   const blocks=checked(await admin.from('balamani_blocked_dates').select('day').order('day'));
   const members=actor.owner?checked(await admin.from('balamani_members').select('id,email,full_name,dog_name,active').order('created_at',{ascending:false}).limit(500)):[];
   const occupancy=checked(await admin.rpc('balamani_occupancy'));
   return reply({actor,bookings,blocks:blocks.map((x:any)=>x.day),members,occupancy});
  }
  if(['invite','recovery','bootstrap'].includes(action)) {
   if(!bootstrap && !actor.owner) return reply({error:'Owner access required'},403);
   const email=String(body.email||'').trim().toLowerCase();
   if(email.length>254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return reply({error:'Enter a valid email address'},400);
   if(bootstrap && !checked(await admin.rpc('balamani_is_owner_email',{p_email:email}))) return reply({error:'Bootstrap is restricted to configured owners'},403);
   const existing=checked(await admin.from('balamani_members').select('id,active').eq('email',email).maybeSingle());
   if(existing && !existing.active) return reply({error:'This account is inactive'},403);
   if(action==='recovery' && !existing) return reply({error:'Invite this client first'},400);
   // Limit credential-link generation per owner; links are never stored in application tables.
   if(actor){const since=new Date(Date.now()-3600000).toISOString();const recent=await admin.from('balamani_audit').select('id',{count:'exact',head:true}).eq('actor_id',actor.id).eq('action','link').gte('created_at',since);if(recent.error)throw recent.error;if((recent.count||0)>=20)return reply({error:'Hourly invitation limit reached. Try later.'},429);}
   const type=existing?'recovery':'invite';
   const data=checked(await admin.auth.admin.generateLink({type,email,options:{redirectTo:site}}));
   if(!existing) checked(await admin.from('balamani_members').insert({id:data.user.id,email}));
   checked(await admin.from('balamani_audit').insert({actor_id:actor?.id||null,action:'link',target_id:data.user.id}));
   // Fragment avoids putting the credential into HTTP requests, referers, or Pages access logs.
   const link=site+'#token_hash='+encodeURIComponent(data.properties.hashed_token)+'&type='+type;
   return reply({link,email,type});
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
