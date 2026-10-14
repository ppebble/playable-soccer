# Soccer 0.2 contracts

Module `PlayableSoccer`; inventory FullType `PlayableSoccer.SportsSoccerBall`.
Ball fields: `id,owner,itemId,x,y,z,h,vx,vy,vz`, optional `match`, cosmetic `kickSerial,kicker,kickDx,kickDy,lob`.
World x/y use tiles; z is the integer floor; h/vz use floor-height units (3 horizontal tile units per floor). No screen coordinates are persisted or sent to the server.

Client intents: `start {itemId}`, `kick {id,dx,dy,power,lob}`, `stop {id}`, `sync {}`, `configure {id,goalA={ax,ay,bx,by},goalB={ax,ay,bx,by},center={x,y}}`, `reset {id}`, `team {id,team='A'|'B'}`.
Server responses: `state {revision,balls={...}}`, `notice {key}`. SP uses PSServer.command / PSClient.receive; MP uses native client/server command events. Nested state is copied to avoid SP aliasing.

Match: goals.A/B are world-space mouths with inward normals, width and endpoints. Center lies inside both. Scores go to the opposite team of the crossed goal, including own goals; last toucher does not determine score. Full-ball entry is swept per physics substep with post/height/direction checks. Goal pause is two seconds; reset retains ball identity and score. Owner alone configures, resets or ends. Teams are lightweight bookkeeping without AI or role enforcement.

Input: LMB charge/release ground kick, RMB charge/release lob; cursor sets direction. Esc cancels a charge first, otherwise leaves controls. Native press capture blocks default aiming/context only for that press. UI/other timed actions retain ordinary behavior; own cosmetic gesture does not disable sports input. Zero-area noninteractive HUD has score/messages/power at top center.

PSProjection.screenToWorld(index,sx,sy,z), worldToScreen(index,x,y,z), available(), register(adapter) form the camera boundary. Adapters must supply both transforms. Viewpoint detection fails closed for vanilla-coordinate placement/aim. This is preparation, not Viewpoint support. Detached rendering needs separate validation/replacement for alternate cameras; coordinate adaptation alone is insufficient.

PSSetup.active(),click(button),cancel(),menu(index,context,C) own five-point placement. PSHUD.render(panel,C) owns UI/projected guides. PSMotion.play(player,lob,dx,dy) queues only a cosmetic action for the accepted local kicker, referencing a native downward foot clip through an event-free owned node. It is not an authored forward-kick asset.

No age/bounce deletion, inventory consumption or collectible display proxies. Unloaded/unsupported terrain stops movement. Session state ends on explicit stop or server shutdown, no save/restart recovery. Collision is conservative tile-based, without precise furniture/vehicle/ceiling or airborne cross-floor simulation.
