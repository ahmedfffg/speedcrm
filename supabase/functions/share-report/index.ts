import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const cors={ "Access-Control-Allow-Origin":"*", "Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type", "Access-Control-Allow-Methods":"POST, OPTIONS" };
const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{...cors,"Content-Type":"application/json"}});
const allowed:Record<string,string[]> = {
 customers:["name","type","area","address","phone","status","importance","created_at","next_follow_up"],
 visits:["visit_date","visit_time","area","met_person","result","quote_amount","order_amount","notes"],
 sales:["sale_date","total_amount","status","invoice_number","notes"]
};
async function digest(value:string){const data=new TextEncoder().encode(value);const hash=await crypto.subtle.digest("SHA-256",data);return [...new Uint8Array(hash)].map(x=>x.toString(16).padStart(2,"0")).join("")}
Deno.serve(async req=>{
 if(req.method==="OPTIONS")return new Response("ok",{headers:cors});
 if(req.method!=="POST")return json({error:"Method not allowed"},405);
 const url=Deno.env.get("SUPABASE_URL")!, service=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
 const admin=createClient(url,service,{auth:{persistSession:false}});
 const body=await req.json().catch(()=>({}));
 const action=body.action;
 if(action==="create"||action==="revoke"){
  const auth=req.headers.get("Authorization")||"";
  const userClient=createClient(url,Deno.env.get("SUPABASE_ANON_KEY")!,{global:{headers:{Authorization:auth}}});
  const {data:{user},error}=await userClient.auth.getUser();
  if(error||!user)return json({error:"Unauthorized"},401);
  if(action==="revoke"){
   const {error:e}=await admin.from("share_links").update({revoked_at:new Date().toISOString()}).eq("id",body.id).eq("created_by",user.id);
   if(e)return json({error:e.message},400);return json({ok:true});
  }
  const type=String(body.data_type||"");
  if(!["customers","visits","sales","monthly_report"].includes(type))return json({error:"Invalid data type"},400);
  const raw=crypto.randomUUID()+crypto.randomUUID()+crypto.randomUUID();
  const fields=(Array.isArray(body.fields)?body.fields:allowed[type]||[]).filter((f:string)=>(allowed[type]||[]).includes(f));
  const {data,error:e}=await admin.from("share_links").insert({created_by:user.id,token_hash:await digest(raw),data_type:type,filters:body.filters||{},expires_at:body.expires_at||null,require_auth:!!body.require_auth}).select("id").single();
  if(e)return json({error:e.message},400);
  const {error:p}=await admin.from("share_link_permissions").insert({share_link_id:data.id,resource_type:type,allowed_fields:fields,can_view:true,can_edit:false,can_delete:false});
  if(p){await admin.from("share_links").delete().eq("id",data.id);return json({error:p.message},400)}
  return json({id:data.id,token:raw});
 }
 if(action==="view"){
  const token=String(body.token||"");if(token.length<50)return json({error:"Invalid link"},404);
  const {data:link,error}=await admin.from("share_links").select("id,created_by,data_type,filters,expires_at,require_auth,revoked_at").eq("token_hash",await digest(token)).maybeSingle();
  if(error||!link||link.revoked_at||(link.expires_at&&new Date(link.expires_at)<new Date()))return json({error:"Link expired or unavailable"},404);
  if(link.require_auth){const auth=req.headers.get("Authorization")||"";const client=createClient(url,Deno.env.get("SUPABASE_ANON_KEY")!,{global:{headers:{Authorization:auth}}});const {data:{user}}=await client.auth.getUser();if(!user)return json({error:"Authentication required"},401)}
  const {data:perm}=await admin.from("share_link_permissions").select("allowed_fields,record_ids,can_view,can_edit,can_delete").eq("share_link_id",link.id).single();
  if(!perm?.can_view)return json({error:"Forbidden"},403);
  const table=link.data_type;const fields=(perm.allowed_fields||[]).filter((f:string)=>(allowed[table]||[]).includes(f));
  let query=admin.from(table).select(fields.join(",")).eq("user_id",link.created_by).limit(500);
  if(perm.record_ids?.length)query=query.in("id",perm.record_ids);
  if(link.filters?.area&&["customers","visits"].includes(table))query=query.eq("area",link.filters.area);
  if(link.filters?.customer_id&&["visits","sales"].includes(table))query=query.eq("customer_id",link.filters.customer_id);
  const {data,error:e}=await query;
  if(e)return json({error:"Unable to load shared report"},500);
  await admin.from("share_links").update({last_used_at:new Date().toISOString()}).eq("id",link.id);
  return json({data_type:table,fields,data,read_only:true});
 }
 return json({error:"Unknown action"},400);
});