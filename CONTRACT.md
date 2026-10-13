# Initial internal contract

Module `PlayableSoccer`; inventory FullType `PlayableSoccer.SportsSoccerBall`.
Ball table `{id,owner,x,y,z,h,vx,vy,vz}`: z is integer world floor; h is height in tile units above floor. State packet `{revision,balls={...}}`; positions and velocities are authoritative server samples, no Java objects.

Client->server commands: `start {itemId}`, `kick {id,dx,dy,power}`, `stop {id}`, `sync {}`. Power normalized 0..1; initial charge max 0.9s. Ground kick only for initial prototype. Server validates all finite numeric inputs, near-ball distance, player alive/on foot/same floor, command rates, owner-only stop. Start needs owned exact sports item in main inventory, does not remove it, at most one active ball per owner. Other nearby players can kick without consuming or owning a second ball. No auto-delete on rest, age or bounce. Unloaded/unsupported terrain blocks motion safely. Sessions last until explicit owner stop or server shutdown; do not mutate saves.

Server->client: `state` as above, `notice {key}` (translation key). SP client calls PSServer.command(player,command,args), server emits via PSClient.receive(command,args); MP uses OnClientCommand / sendClientCommand and OnServerCommand / sendServerCommand. Both server and client load `PS_Core`.

Core API: `PSCore.finite(n)`, `PSCore.newBall(x,y,z)`, `PSCore.step(ball,dt,collision)` and `PSCore.kick(ball,dx,dy,power)`; collision(ball,fromX,fromY,toX,toY) returns blockedX,blockedY. Core handles dt subdivision; no lifetime deletion. Unit tests must verify repeated wall bounces, resting retention, re-kicking, nonfinite input and coarse-step collision handling.

PSClient API: `PSClient.start(player,item)`, `PSClient.stop()`, `PSClient.receive(command,args)`. Inventory menu owned by leader calls start/stop; client owns world context join-nearby entry if useful. Conversion must refuse active sports item: client selected state and server authoritative helper `PSServer.isItemActive(player,item)` available for complete() checks. Server must revalidate item each tick? Do not delete ball if owner disconnects or moves away; lock conversion while active, verify item on start only. 3D presentation must not generate persistent/collectable duplicates; investigate direct native model render or isolated render proxy. Document unverified limitations; do not silently fake proof.
