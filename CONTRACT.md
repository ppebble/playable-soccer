# Soccer 0.3 contracts

Module `PlayableSoccer`; inventory FullType `PlayableSoccer.SportsSoccerBall`.
Ball fields: `id,owner,itemId,x,y,z,h,vx,vy,vz`, optional `match`, cosmetic `kickSerial,kicker,kickDx,kickDy,lob,dribble`.
World x/y use tiles; z is the integer floor; h/vz use floor-height units (3 horizontal tile units per floor). No screen coordinates are persisted or sent to the server.

Client intents: `start {itemId}`, `kick {id,dx,dy,power,lob}`, `dribble {id,dx,dy}`, `stop {id}`, `sync {}`, `configure {id,goalA={ax,ay,bx,by},goalB={ax,ay,bx,by},center={x,y}}`, `reset {id}`, `team {id,team='A'|'B'}`.
Server responses: `state {revision,balls={...}}`, `notice {key}`. SP uses PSServer.command / PSClient.receive; MP uses native client/server command events. Nested state is copied to avoid SP aliasing.

Match: goals.A/B are world-space mouths with inward normals, width and endpoints. Center lies inside both. Scores go to the opposite team of the crossed goal, including own goals; last toucher does not determine score. Full-ball entry is swept per physics substep with post/height/direction checks. Goal pause is two seconds; reset retains ball identity and score. Owner alone configures, resets or ends. Teams are lightweight bookkeeping without AI or role enforcement.

Input: LMB charge/release pass or low lifted shot at >=80%, RMB charge/release high lob; cursor sets direction. Esc cancels a charge first, otherwise leaves controls. The HUD consumes its Escape press/release before global events; the exit release remains consumed and the next inactive Escape reaches the vanilla menu. Paused game, text entry and dead players retain vanilla Escape. Native press capture blocks default aiming/context only for that press. UI/other timed actions retain ordinary behavior; own cosmetic gesture does not disable sports input. Zero-area noninteractive HUD has score/messages/power at top center.

PSProjection.screenToWorld(index,sx,sy,z), worldToScreen(index,x,y,z), available(), register(adapter) form the camera boundary. Adapters must supply both transforms. Viewpoint detection fails closed for vanilla-coordinate placement/aim. This is preparation, not Viewpoint support. Detached rendering needs separate validation/replacement for alternate cameras; coordinate adaptation alone is insufficient.

PSSetup.active(),click(button),cancel(),menu(index,context,C) own four-click, two-line placement with automatic midpoint restart. PSHUD.render(panel,C) owns UI/projected guides. PSMotion.play(player,lob,dx,dy) queues only a cosmetic action for the accepted local kicker, referencing a native downward foot clip through an event-free owned node. It is not an authored forward-kick asset.

No age/bounce deletion, inventory consumption or collectible display proxies. Unloaded/unsupported terrain stops movement. Session state ends on explicit stop or server shutdown, no save/restart recovery. Collision is conservative tile-based, without precise furniture/vehicle/ceiling or airborne cross-floor simulation.

Running/sprinting ground-contact dribble: selected ball, no held mouse/charge, <=0.8 tile contact, 0.4s accepted-touch server cooldown, clear path, server movement/facing direction. Dribble uses measured running speed +2.5, clamped to 6–12 tiles/s; client cannot supply speed. Ground/air horizontal drag both 3. Manual target distances: LEFT=1.5+16.9*p, RIGHT=.65+17.75*p^1.4. Initial speed=sqrt(6*distance). LEFT target peak0 below80%, .02–.15 floor at80–100%; RIGHT peak .35–1.8 floor independent of horizontal speed. Goal state freezes all velocity/gravity and publishes immediately; client snaps phase transitions.

HUD mouse invariant: no screen hit rectangle, explicit false mouse callbacks. Native inventory world-drop uses isPointOver without checking consumeMouseEvents; a full-screen transparent panel blocks drops even with mouse consumption disabled. Do not expand HUD bounds for rendering; PSHUD draws in screen coordinates.

Dribble acquisition retries every 100ms near displayed/latest ball; rejected attempts do not consume the 400ms accepted-touch cooldown. Server may accept a <=150ms observed swept contact (<=1.2 tile segment, endpoint <=manual reach), validates player path and ball contact LOS, and still requires running/sprinting and a grounded ball. Render uses 16 Z-only spin phases with fixed X/Y; added shadow exists only above h=.025 and no height guide is drawn.
