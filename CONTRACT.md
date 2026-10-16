# Soccer release contracts

Module `PlayableSoccer`; inventory FullType `PlayableSoccer.SportsSoccerBall`. Source gameplay and native regression tests stay under `tests/`; only `Contents/mods/PlayableSoccer` is packaged.

## Authority and lifecycle

Server owns physics, possession, scoring and XP. Ball fields include `id,owner,itemId,x,y,z,h,vx,vy,vz`, optional `match`, player `possession`, and accepted kick metadata. World x/y use tiles, z integer floors, h/vz floor-height units (three tiles per floor). Screen coordinates never enter authority.

Intents: start, stop, sync, control, kick, tackle, configure, reset, restart and team. Configure accepts mode `match` (default) or `practice`; practice requires goalA only and a restart point, competitive requires goalA/B and their interior center. State snapshots deep-copy nested tables for SP; MP uses native commands. Only owner configures, resets, restarts or ends a session. Solo practice only admits its owner. No simulated players, test regions, automatic shots/passes or diagnostic tracing ship.

Competitive matches end at five goals with `phase=finished` and `winner`. Earlier goals pause two seconds then restart the same ball. Reset recalls the ball without clearing scores or resuming a finished match. Explicit owner restart starts 0:0. Practice counts goals without a score limit; only owner stop ends it. Goal entry uses swept full-ball crossing with post, direction and height checks. Session state is not saved across server shutdown.

## Controls and presentation

LMB charges pass/shot, RMB charges lob, cursor sets direction. Full charge takes450ms; >=80% LMB lifts, >=90% chooses the stronger cosmetic kick. Space replaces shove only during soccer control. The native shove clip is used for the cosmetic tackle; actual tackle is server validated, requires an opposing holder, range1.4, facing and clear path, cooldown0.8s. Victim uses an isolated fall node without health damage.

Esc cancels charge/setup or opens the soccer menu. The next inactive Escape returns to vanilla. Zero-area HUD with explicit false mouse callbacks is mandatory: even a transparent fullscreen hit rectangle blocks native inventory drops. Normal UI/text-entry/drag/actions retain native input. Owned cosmetic motion allows locomotion.

One-goal practice uses two clicks; competitive uses four. Goals are2–10tiles wide with restart point at least2tiles inside. Score/messages/gauge are top center. PSProjection owns all input/projection adaptation. Viewpoint has no validated adapter; detection blocks unsupported placement/aim. Detached ball rendering and any alternate camera require independent live verification.

## Possession, physics and XP

Only active participants acquire a free ball within1.15tiles and1.35m height, including fast incoming shots checked each physics substep. Walls, floors, exclusive ownership and shooter reacquisition grace remain enforced. Held ball follows0.4tiles ahead of current facing, bounded24–32tiles/s. Local holder display uses current player pose with fresh authority and collision gates. Server separation/grace bounds prevent teleports from dragging the ball.

Motion runs at1.4x after a0.25s catch-up cap. LEFT distance=1.5+22.42*p; RIGHT=.65+27.35*p^1.4. Airborne forward momentum persists through descent and bounce; ground drag3 slows settled rolling. Initial horizontal speed solves distance including total flight/bounces and final roll. LEFT peak is0 below80%, .02–.40floors at80–100%, with35% gravity during the first lifted flight only; rebounds use ordinary gravity. RIGHT peak=(.7+2.9*p)*.85floors with ordinary gravity. Goal/finished server phases freeze motion.

Each accepted manual kick awards native server addXp Strength1 and Aiming1. Rejected inputs, dribble and finished games award none. Native XP modifiers apply. No lifetime/bounce deletion, consumed sports balls or registered collectible render proxies. Unloaded/unsupported terrain halts movement. Collision is tile-based, without precise furniture/vehicle/ceiling or airborne cross-floor handling. Render rotation uses16Z-only phases to avoid stock mesh pivot orbit; extra shadow appears only above h=.025.
