# Playable Soccer

Independent B42 prototype. Namespace runtime globals PS_/PSCore/PSServer/PSClient and items PlayableSoccer. Upstream game and Workshop files are read-only. No upstream code/assets copied. Existing sibling mods, saves and server presets must remain unchanged. Server owns ball simulation and validates intents; inventory conversion uses native B42 timed-action completion. Sports balls are not consumed by practice. Never publish without explicit instruction. Report Kahlua/source checks, installed hashes and actual gameplay separately.

Initial scope: reversible soccer-ball conversion, explicit practice start/end, charge kick, persistent ball, ground friction, gravity/bounce, repeated wall collision. No automatic age/bounce deletion, AI, scoring or teams. Session persistence means the running server session; save/restart recovery is a separate feature.
