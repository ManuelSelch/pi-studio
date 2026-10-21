const $ = (s) => document.querySelector(s);
const params = new URLSearchParams(location.search);
const ios = params.get('layout') === 'ios' || (!params.has('layout') && innerWidth < 650);
document.body.classList.toggle('ios', ios);
document.querySelector(`.review nav a[href="?layout=${ios ? 'ios' : 'mac'}"]`).classList.add('selected');
const sessions = [
 {id:'auth',title:'Fix authentication',project:'pi-studio',state:'running',open:true,draft:'',messages:[]},
 {id:'sdk',title:'Review SDK',project:'pi-chat',state:'attention',open:true,unread:true,draft:'',messages:[]},
 {id:'design',title:'Compact session layout',project:'pi-studio',state:'idle',open:true,draft:'Keep the toolbar to a single row.',messages:[]},
 {id:'tests',title:'Run integration tests',project:'pi-chat',state:'running',open:false,unread:true,draft:'',messages:[]},
 {id:'history1',title:'Endpoint settings',project:'pi-studio',state:'idle',open:false,history:true,date:'Yesterday',draft:'',messages:[]},
 {id:'history2',title:'Session recovery',project:'pi-studio',state:'idle',open:false,history:true,date:'Mon',draft:'',messages:[]},
 {id:'history3',title:'Transport reconnect',project:'pi-chat',state:'idle',open:false,history:true,date:'Yesterday',draft:'',messages:[]},
 {id:'quick',title:'Weekend ideas',project:'Quick Chats',state:'idle',open:false,history:true,date:'Sun',draft:'',messages:[]}
];
let active = params.get('state') === 'attention' ? 'sdk' : 'auth';
let filter = '', expanded = new Set(['pi-studio']), overviewMode = 'all', count = 0, toastTimer;
if(params.get('state') === 'empty') { sessions.forEach(s=>{s.open=false;s.state='idle'}); active=null; }
const escape = (v) => String(v).replace(/[&<>"']/g, c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const dot = s => `<span class="state-dot ${s.state}" aria-label="${s.state}"></span>`;
function toast(message){ $('#toast').textContent=message; $('#toast').style.display='block'; clearTimeout(toastTimer);toastTimer=setTimeout(()=>$('#toast').style.display='none',3600); }
function select(id){ const s=sessions.find(s=>s.id===id); if(!s)return;s.open=true;s.unread=false;active=id;$('#app').classList.remove('browsing');$('#overview').hidden=true;render(); }
function close(id){const s=sessions.find(s=>s.id===id);const previous=sessions.filter(s=>s.open);s.open=false;if(active===id){const index=previous.indexOf(s);active=previous[index+1]?.id||previous[index-1]?.id||null;}if(s.state==='running'||s.state==='attention')toast('Tab closed. Session remains available in Background activity.');render();}
function create(project){const id=`new${++count}`;sessions.push({id,title:'New conversation',project:project||sessions.find(s=>s.id===active)?.project||'Quick Chats',state:'idle',open:true,draft:'',messages:[]});select(id);$('#draft').focus();}
function renderSidebar(){
 const match=s=>!filter||`${s.title} ${s.project}`.toLowerCase().includes(filter.toLowerCase());
 const background=sessions.filter(s=>s.state!=='idle'&&match(s));
 $('#sidebar').innerHTML=`<div class="sidebar-head"><span class="traffic" aria-hidden="true"><i></i><i></i><i></i></span><span class="sidebar-title">Sessions</span><button class="sidebar-close desktop-hidden" aria-label="Close projects">✕</button></div><input class="search" aria-label="Search sessions" placeholder="Search sessions…" value="${escape(filter)}"><div class="sidebar-scroll"><div class="section-label">Activity <span>${background.length}</span></div>${background.map(s=>`<button class="history-row" data-select="${s.id}">${dot(s)}<span>${escape(s.title)}</span><small>${s.state==='attention'?'Needs you':'Running'}</small></button>`).join('')||'<div class="overview-foot" style="padding-left:19px">No background activity</div>'}<div class="section-label" style="margin-top:25px">Projects & history</div>${['pi-studio','pi-chat','Quick Chats'].map(p=>{const items=sessions.filter(s=>s.project===p&&match(s));const show=expanded.has(p)||!!filter;return `<div class="project-row ${sessions.find(s=>s.id===active)?.project===p?'project-selected':''}"><button data-project="${p}" aria-expanded="${show}">${show?'⌄':'›'} &nbsp; ${p==='Quick Chats'?'☏':'▱'} &nbsp;${p}</button><button data-create="${p}" aria-label="New session in ${p}">＋</button></div>${show?items.map(s=>`<button class="history-row" data-select="${s.id}"><span>${escape(s.title)}</span><small>${s.open?'Open':s.date||'Recent'}</small></button>`).join(''):''}`;}).join('')}</div><div class="sidebar-bottom"><span class="connection-dot"></span>Connected · Homelab<button id="settings" aria-label="Connection settings">⚙</button></div>`;
 $('#sidebar .search').addEventListener('input',e=>{const start=e.target.selectionStart;filter=e.target.value;renderSidebar();const input=$('#sidebar .search');input.focus();input.setSelectionRange(start,start);});
 $('#sidebar .sidebar-close').onclick=()=>$('#app').classList.remove('browsing');
 $('#settings').onclick=()=>toast('Connected to Homelab. Endpoint settings are omitted from this concept.');
 $('#sidebar').querySelectorAll('[data-project]').forEach(b=>b.onclick=()=>{const p=b.dataset.project;expanded.has(p)?expanded.delete(p):expanded.add(p);renderSidebar();});
 $('#sidebar').querySelectorAll('[data-select]').forEach(b=>b.onclick=()=>select(b.dataset.select));
 $('#sidebar').querySelectorAll('[data-create]').forEach(b=>b.onclick=()=>create(b.dataset.create));
}
function renderTabs(){
 $('#tabs').innerHTML=sessions.filter(s=>s.open).map(s=>`<div class="tab ${active===s.id?'active':''}"><button role="tab" aria-selected="${active===s.id}" aria-controls="conversation" data-select="${s.id}">${dot(s)}<span class="tab-label">${escape(s.title)}</span>${s.unread?'<span class="unread">•</span>':''}</button><button data-close="${s.id}" aria-label="Close tab ${escape(s.title)}">×</button></div>`).join('');
 $('#tabs').querySelectorAll('[data-select]').forEach(b=>b.onclick=()=>select(b.dataset.select));
 $('#tabs').querySelectorAll('[data-close]').forEach(b=>b.onclick=()=>close(b.dataset.close));
}
function renderConversation(){
 const s=sessions.find(s=>s.id===active);
 $('#context').textContent=s?.project||'Pi Studio';$('#draft').value=s?.draft||'';$('#draft').disabled=!s;$('#send').disabled=!s;
 if(!s){$('#transcript').innerHTML='<h1 class="conversation-title">A little space to think.</h1><p class="conversation-meta">Start a conversation, or open a previous session from Projects.</p><button id="start-empty" style="padding:10px 15px;background:#edf5f0;color:#34795c">＋ New conversation</button>';$('#session-status').innerHTML='';$('#start-empty').onclick=()=>create();return;}
 let content='';
 if(s.id==='auth')content='<div class="message user">Simplify the connection flow and make sure reconnecting doesn’t create duplicate sessions.</div><div class="message"><div class="assistant-label">PI</div><p>I found the connection and session-selection paths. I’m separating connection ownership from the selected conversation so switching tabs won’t interrupt another session.</p><div class="tool"><span>⌘</span> Read SessionController.swift <span>✓</span></div><p>The change will keep three things independent:</p><ul><li>The connection to your Pi server</li><li>The sessions running on that server</li><li>The conversation currently visible in a tab</li></ul><div class="tool"><span>⌘</span> Checking reconnect behavior… <span>Running</span></div></div>';
 else if(s.id==='sdk')content='<div class="message user">Review the SDK changes and run the transport tests.</div><div class="message"><div class="assistant-label">PI</div><p>The review is complete. The transport tests need a local test server.</p><p><strong>Allow starting the isolated test server?</strong></p><p>This will run only against a temporary fixture, not your live sessions.</p><button id="allow" style="background:#edf5f0;color:#34795c;padding:9px 14px">Allow & continue</button></div>';
 else if(s.id==='design')content='<div class="message user">Suggest a compact layout for multiple sessions on Mac and iPhone.</div><div class="message"><div class="assistant-label">PI</div><p>Keep projects and history in the sidebar. Open conversations get their own tabs.</p><p>On iPhone, the tab strip scrolls horizontally. The overview button gives you the full list, including close controls and background activity.</p><p>A tab is just a view onto a session. Closing it does not stop the agent.</p></div>';
 else if(s.id==='tests')content='<div class="message"><div class="assistant-label">PI</div><p>Running the SDK integration suite in the background.</p><div class="tool">Transport tests <span>Running</span></div><p>You can switch to another session while this continues.</p></div>';
 else if(s.history)content='<div class="message user">Let’s pick up where we left off.</div><div class="message"><div class="assistant-label">PI</div><p>This is a saved conversation reopened from project history. It now has its own tab.</p><p>Your other open sessions and their drafts are unchanged.</p></div>';
 $('#transcript').innerHTML=`<h1 class="conversation-title">${escape(s.title)}</h1><div class="conversation-meta">${escape(s.project)} · ${s.history?'Saved conversation':'Current session'}</div>${content}${s.messages.map(m=>`<div class="message ${m.role==='user'?'user':''}">${m.role==='assistant'?'<div class="assistant-label">PI</div>':''}${escape(m.text)}</div>`).join('')}${!content&&!s.messages.length?'<p class="conversation-meta">What would you like to work on?</p>':''}`;
 $('#session-status').innerHTML=s.state==='running'?`${dot(s)} Working in background <button id="stop">Stop</button>`:s.state==='attention'?`${dot(s)} Waiting for your approval`:'<span>Ready</span>';
 if($('#stop'))$('#stop').onclick=()=>{s.state='idle';render();toast('Session stopped. Other sessions are unaffected.');};
 if($('#allow'))$('#allow').onclick=()=>{s.state='running';s.messages.push({role:'assistant',text:'Approved. The isolated test run is now in progress (simulated).'});render();};
}
function renderOverview(){const opened=sessions.filter(s=>s.open), background=sessions.filter(s=>!s.open&&s.state!=='idle');const row=s=>`<div class="overview-session ${s.id===active?'active':''}"><button data-select="${s.id}">${dot(s)} &nbsp;${escape(s.title)}<small>${escape(s.project)} · ${s.state==='attention'?'Needs attention':s.state==='running'?'Running':'Idle'}${s.unread?' · Unread':''}</small></button>${s.open?`<button data-close="${s.id}" aria-label="Close tab ${escape(s.title)}">×</button>`:''}</div>`;$('#overview').innerHTML=`<div class="overview-head">${overviewMode==='activity'?'Background activity':'Open sessions'}<button id="dismiss-overview" class="icon" aria-label="Close session overview">✕</button></div>${overviewMode==='all'?opened.map(row).join('')||'<p class="overview-foot">No open sessions.</p>':opened.filter(s=>s.state!=='idle').map(row).join('')}<div class="overview-section">Running without an open tab</div>${background.map(row).join('')||'<p class="overview-foot">None</p>'}<button id="overview-new" style="padding:12px;width:100%;text-align:left">＋ New conversation</button><div class="overview-foot">Closing a tab leaves its session on the server. Stop an agent from its conversation.</div>`;$('#dismiss-overview').onclick=()=>$('#overview').hidden=true;$('#overview-new').onclick=()=>create();$('#overview').querySelectorAll('[data-select]').forEach(b=>b.onclick=()=>select(b.dataset.select));$('#overview').querySelectorAll('[data-close]').forEach(b=>b.onclick=()=>close(b.dataset.close));}
function render(){renderSidebar();renderTabs();renderConversation();renderOverview();$('#running-count').textContent=sessions.filter(s=>s.state==='running').length;}
$('#browse').onclick=()=>{if(ios)$('#app').classList.toggle('browsing');else $('#app').classList.toggle('sidebar-hidden');$('#overview').hidden=true;};
$('#shade').onclick=()=>$('#app').classList.add('sidebar-hidden');
$('#new').onclick=()=>create();
function toggleOverview(mode){const already=!$('#overview').hidden&&overviewMode===mode;overviewMode=mode;renderOverview();$('#overview').hidden=already;}
$('#overview-button').onclick=()=>toggleOverview('all');$('#activity').onclick=()=>toggleOverview('activity');
$('#draft').oninput=e=>{const s=sessions.find(s=>s.id===active);if(s)s.draft=e.target.value;};
$('#composer').onsubmit=e=>{e.preventDefault();const s=sessions.find(s=>s.id===active);if(!s||!s.draft.trim())return;if(s.state==='attention'){toast('Resolve the approval request before sending.');return;}s.messages.push({role:'user',text:s.draft.trim()},{role:'assistant',text:'Message received in this session only. This is a layout prototype; no agent or server was contacted.'});s.draft='';renderConversation();$('#transcript').scrollTop=$('#transcript').scrollHeight;};
document.addEventListener('keydown',e=>{if(e.key==='Escape'){$('#overview').hidden=true;$('#app').classList.remove('browsing');}if((e.metaKey||e.ctrlKey)&&/^[1-9]$/.test(e.key)){const s=sessions.filter(s=>s.open)[Number(e.key)-1];if(s){e.preventDefault();select(s.id);}}});
render();
if(params.get('state')==='overview'){overviewMode='all';renderOverview();$('#overview').hidden=false;}
if(params.get('state')==='projects')$('#app').classList.add('browsing');
if(!ios&&innerWidth<650)$('#app').classList.add('sidebar-hidden');
