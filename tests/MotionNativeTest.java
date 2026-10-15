import java.nio.file.*;
import java.util.*;

/** Installed native contracts, not rendered motion or multiplayer evidence. */
public final class MotionNativeTest {
    public static void main(String[] args) throws Exception {
        verifyFall();
        verifySoccerFall(args[0]);
        verifyNodeCache();
        verifyTackle(args[0]);
        verifyStrongKick(args[0]);
        Class<?> nodeType=Class.forName("zombie.core.skinnedmodel.advancedanimation.AnimNode");
        Class<?> vars=Class.forName("zombie.core.skinnedmodel.advancedanimation.AnimationVariableSource");
        Class<?> source=Class.forName("zombie.core.skinnedmodel.advancedanimation.IAnimationVariableSource");
        Object node=nodeType.getMethod("Parse",String.class).invoke(null,Path.of(args[0],"media/AnimSets/player/actions/PS_KickGesture.xml").toString());
        if(node==null || !"Bob_AttackFloorStamp".equals(nodeType.getField("animName").get(node))) throw new AssertionError("Real native foot clip required");
        if(!((List<?>)nodeType.getField("events").get(node)).isEmpty()) throw new AssertionError("Cosmetic motion must not trigger combat events");
        Object values=vars.getConstructor().newInstance();
        for(String name:new String[]{"PS_KickGesture","Stomp","Eat","","PB_BatStroke"}) {
            vars.getMethod("setVariable",String.class,String.class).invoke(values,"PerformingAction",name);
            boolean selected=(Boolean)nodeType.getMethod("checkConditions",source).invoke(node,values);
            if(selected!=name.equals("PS_KickGesture")) throw new AssertionError("Action condition leaks");
        }
        Set<String> bones=new HashSet<>();
        for(Object weight:(List<?>)nodeType.getField("subStateBoneWeights").get(node)) bones.add((String)weight.getClass().getField("boneName").get(weight));
        if(!bones.equals(Set.of("Bip01_L_Thigh","Bip01_R_Thigh"))) throw new AssertionError("Keep root motion and hands outside leg mask");
        String clip=Files.readString(Path.of("media/anims_X/Bob/Bob_AttackFloorStamp.x"));
        for(String bone:bones) if(!clip.contains("Frame "+bone)) throw new AssertionError("Missing installed bone "+bone);
        var rate=java.util.regex.Pattern.compile("AnimTicksPerSecond\\s*\\{\\s*(\\d+);").matcher(clip);
        if(!rate.find()) throw new AssertionError("Missing native timing");
        var times=java.util.regex.Pattern.compile("(?m)^\\s*(\\d+);[34];").matcher(clip);
        int last=0;while(times.find()) last=Math.max(last,Integer.parseInt(times.group(1)));
        if(last/Double.parseDouble(rate.group(1))/1.5+0.12>32.0/30) throw new AssertionError("Gesture timeout truncates clip");
        Class<?> action=Class.forName("zombie.characters.CharacterTimedActions.BaseAction");
        action.getMethod("setActionAnim",String.class);
        action.getMethod("setBlockMovementEtc",boolean.class);
        action.getMethod("setUseProgressBar",boolean.class);
        Class<?> player=Class.forName("zombie.characters.IsoPlayer");
        player.getMethod("isLocalPlayer");player.getMethod("isMoving");
        System.out.println("PASS native soccer gesture clip/bones, event-free node selection, bounded duration and action APIs; visual playback untested");
    }

    private static void verifySoccerFall(String mod) throws Exception {
        // Standalone harness has no bootstrapped filesystem; resolve native x_extends
        // against the installed game without loading mods or writing user state.
        Class<?> fsType=Class.forName("zombie.ZomboidFileSystem");
        Object folder=fsType.getField("base").get(fsType.getField("instance").get(null));
        folder.getClass().getMethod("set",java.io.File.class).invoke(folder,Path.of(".").toAbsolutePath().normalize().toFile());
        Class<?> nodeType=Class.forName("zombie.core.skinnedmodel.advancedanimation.AnimNode");
        Class<?> stateType=Class.forName("zombie.core.skinnedmodel.advancedanimation.AnimState");
        Class<?> vars=Class.forName("zombie.core.skinnedmodel.advancedanimation.AnimationVariableSource");
        Class<?> source=Class.forName("zombie.core.skinnedmodel.advancedanimation.IAnimationVariableSource");
        Object state=stateType.getConstructor().newInstance();
        Object own=nodeType.getMethod("Parse",String.class).invoke(null,Path.of(mod,"media/AnimSets/player/knockeddown/PS_SoccerFall.xml").toString());
        if(!"Bob_HitReact02_Walking".equals(nodeType.getField("animName").get(own))) throw new AssertionError("Keep backward recovery clip");
        try(var files=Files.list(Path.of("media/AnimSets/player/knockeddown"))) {
            for(Path p:files.toList()) stateType.getMethod("addNode",nodeType).invoke(state,nodeType.getMethod("Parse",String.class).invoke(null,p.toString()));
        }
        stateType.getMethod("addNode",nodeType).invoke(state,own);
        Object values=vars.getConstructor().newInstance();
        vars.getMethod("setVariable",String.class,boolean.class).invoke(values,"fromBehind",false);
        for(boolean moving:new boolean[]{false,true}) for(boolean running:new boolean[]{false,true}) for(boolean active:new boolean[]{false,true}) {
            vars.getMethod("setVariable",String.class,boolean.class).invoke(values,"isMoving",moving);
            vars.getMethod("setVariable",String.class,boolean.class).invoke(values,"isRunning",running);
            vars.getMethod("setVariable",String.class,boolean.class).invoke(values,"PS_SoccerFall",active);
            List<?> selected=(List<?>)stateType.getMethod("getAnimNodes",source,List.class).invoke(state,values,new ArrayList<>());
            if(active && (selected.size()!=1 || selected.get(0)!=own)) throw new AssertionError("Native fall nodes still blend with soccer fall");
            if(!active && (selected.isEmpty() || selected.contains(own))) throw new AssertionError("Ordinary fall selection changed");
        }
        int sound=0,recovery=0;
        for(Object event:(List<?>)nodeType.getField("events").get(own)) {
            String name=(String)event.getClass().getField("eventName").get(event);
            String parameter=(String)event.getClass().getField("parameterValue").get(event);
            if(name.equals("PlaySoundNoBlend") && parameter.equals("FallLight")) sound++;
            else if(name.equals("setSitOnGround") && parameter.equals("TRUE")) recovery++;
            else throw new AssertionError("Unexpected soccer fall event "+name);
        }
        if(sound!=1 || recovery!=1) throw new AssertionError("Single sound and native recovery event required");
        Class<?> player=Class.forName("zombie.characters.IsoPlayer");
        player.getMethod("setVariable",String.class,boolean.class);player.getMethod("clearVariable",String.class);
        System.out.println("PASS native exclusive soccer fall selection, single blend-aware sound and recovery event; audible result untested");
    }
    private static void verifyStrongKick(String mod) throws Exception {
        Class<?> nodeType=Class.forName("zombie.core.skinnedmodel.advancedanimation.AnimNode");
        Class<?> vars=Class.forName("zombie.core.skinnedmodel.advancedanimation.AnimationVariableSource");
        Class<?> source=Class.forName("zombie.core.skinnedmodel.advancedanimation.IAnimationVariableSource");
        Path path=Path.of(mod,"media/AnimSets/player/actions/PS_StrongKickGesture.xml");
        Object node=nodeType.getMethod("Parse",String.class).invoke(null,path.toString());
        if(node==null || !"Bob_AttackFloorStamp_2Hheavy".equals(nodeType.getField("animName").get(node))) throw new AssertionError("Distinct heavy stamp clip required");
        if(nodeType.getField("useDeferredMovement").getBoolean(node) || nodeType.getField("deferredRotationScale").getFloat(node)!=0) throw new AssertionError("Strong kick cannot drive root motion");
        if(!((List<?>)nodeType.getField("events").get(node)).isEmpty()) throw new AssertionError("Strong kick must not trigger combat");
        Object values=vars.getConstructor().newInstance();
        for(String name:new String[]{"PS_StrongKickGesture","PS_KickGesture","PS_DefendTackle","Stomp","","Eat"}) {
            vars.getMethod("setVariable",String.class,String.class).invoke(values,"PerformingAction",name);
            boolean selected=(Boolean)nodeType.getMethod("checkConditions",source).invoke(node,values);
            if(selected!=name.equals("PS_StrongKickGesture")) throw new AssertionError("Strong kick action condition leaks");
        }
        Set<String> bones=new HashSet<>();
        for(Object weight:(List<?>)nodeType.getField("subStateBoneWeights").get(node)) bones.add((String)weight.getClass().getField("boneName").get(weight));
        if(!bones.equals(Set.of("Bip01_Spine","Bip01_L_Thigh","Bip01_R_Thigh"))) throw new AssertionError("Strong kick body mask changed");
        String clip=Files.readString(Path.of("media/anims_X/Bob/Bob_AttackFloorStamp_2Hheavy.x"));
        for(String bone:bones) if(!clip.contains("Frame "+bone)) throw new AssertionError("Missing installed strong kick bone");
        var rate=java.util.regex.Pattern.compile("AnimTicksPerSecond\\s*\\{\\s*(\\d+);").matcher(clip);
        if(!rate.find()) throw new AssertionError("Missing strong kick timing");
        var times=java.util.regex.Pattern.compile("(?m)^\\s*(\\d+);[34];").matcher(clip);
        int last=0;while(times.find()) last=Math.max(last,Integer.parseInt(times.group(1)));
        double speed=((Number)nodeType.getMethod("getSpeedScale",source).invoke(node,values)).doubleValue();
        double blend=((Number)nodeType.getMethod("getBlendOutTime").invoke(node)).doubleValue();
        if(last/Double.parseDouble(rate.group(1))/speed+blend>32.0/30) throw new AssertionError("Strong kick timeout truncates clip");
        System.out.println("PASS strong kick native variant, body mask, no combat/root motion and duration; appearance untested");
    }
    private static void verifyNodeCache() throws Exception {
        Class<?> managerType=Class.forName("zombie.core.skinnedmodel.advancedanimation.AnimNodeAssetManager");
        Class<?> baseManager=Class.forName("zombie.asset.AssetManager");
        Class<?> pathType=Class.forName("zombie.asset.AssetPath");
        Class<?> assetType=Class.forName("zombie.core.skinnedmodel.advancedanimation.AnimNodeAsset");
        Class<?> status=Class.forName("zombie.asset.Asset$State");
        Object manager=managerType.getField("instance").get(null);
        Object path=pathType.getConstructor(String.class).newInstance("ps-test-cached-node.xml");
        var constructor=assetType.getDeclaredConstructor(pathType,baseManager);constructor.setAccessible(true);
        Object cached=constructor.newInstance(path,manager);
        assetType.getMethod("onCreated",status).invoke(cached,status.getField("READY").get(null));
        Map<Object,Object> table=(Map<Object,Object>)baseManager.getMethod("getAssetTable").invoke(manager);
        table.put("ps-test-cached-node.xml",cached);
        try {
            Class.forName("zombie.core.skinnedmodel.advancedanimation.AnimationSet").getMethod("Reset").invoke(null);
            if(baseManager.getMethod("load",pathType).invoke(manager,path)!=cached)
                throw new AssertionError("Review changed native node cache semantics");
        } finally {table.remove("ps-test-cached-node.xml");}
        System.out.println("PASS native ready node cache survives AnimationSet.Reset and same-path load; live cache content unobserved");
    }
    private static void verifyTackle(String mod) throws Exception {
        Class<?> nodeType=Class.forName("zombie.core.skinnedmodel.advancedanimation.AnimNode");
        Class<?> vars=Class.forName("zombie.core.skinnedmodel.advancedanimation.AnimationVariableSource");
        Class<?> source=Class.forName("zombie.core.skinnedmodel.advancedanimation.IAnimationVariableSource");
        Path path=Path.of(mod,"media/AnimSets/player/actions/PS_DefendTackle.xml");
        Object node=nodeType.getMethod("Parse",String.class).invoke(null,path.toString());
        if(node==null || !"Bob_BiteDefend".equals(nodeType.getField("animName").get(node))) throw new AssertionError("Native unarmed bite-defense clip required");
        String nativeDefense=Files.readString(Path.of("media/AnimSets/player/hitreaction-bite/BiteDefended.xml"));
        if(!nativeDefense.contains("<m_AnimName>Bob_BiteDefend</m_AnimName>") || !nativeDefense.contains("<m_Value>BiteDefended</m_Value>"))
            throw new AssertionError("Installed automatic bite defense changed");
        Class<?> stateType=Class.forName("zombie.core.skinnedmodel.advancedanimation.AnimState");
        Object state=stateType.getConstructor().newInstance();
        try(var files=Files.list(Path.of("media/AnimSets/player/actions"))) {
            for(Path p:files.filter(p->p.toString().endsWith(".xml")).toList()) {
                Object installed=nodeType.getMethod("Parse",String.class).invoke(null,p.toString());
                if(installed!=null) stateType.getMethod("addNode",nodeType).invoke(state,installed);
            }
        }
        stateType.getMethod("addNode",nodeType).invoke(state,node);
        // Reproduce an already-loaded previous owned identity alongside the new
        // node. Never copy or alter installed game assets for this regression.
        Path stalePath=Files.createTempFile("ps-stale-tackle-",".xml");
        Object stale;
        try {
            Files.writeString(stalePath,Files.readString(path).replace("PS_DefendTackle","PS_PushTackle").replace("Bob_BiteDefend","Bob_Shove"));
            stale=nodeType.getMethod("Parse",String.class).invoke(null,stalePath.toString());
        } finally {Files.deleteIfExists(stalePath);}
        stateType.getMethod("addNode",nodeType).invoke(state,stale);
        Object liveValues=vars.getConstructor().newInstance();
        vars.getMethod("setVariable",String.class,String.class).invoke(liveValues,"PerformingAction","PS_DefendTackle");
        for(boolean moving:new boolean[]{false,true}) {
            vars.getMethod("setVariable",String.class,boolean.class).invoke(liveValues,"isMoving",moving);
            List<?> selected=(List<?>)stateType.getMethod("getAnimNodes",source,List.class).invoke(state,liveValues,new ArrayList<>());
            if(selected.size()!=1 || selected.get(0)!=node) {
                for(Object chosen:selected) System.out.println("Selected action: "+nodeType.getField("name").get(chosen));
                throw new AssertionError("Native actions override tackle");
            }
        }
        if(nodeType.getField("useDeferredMovement").getBoolean(node) || nodeType.getField("deferredRotationScale").getFloat(node)!=0) throw new AssertionError("Tackle cannot drive root motion/turning");
        if(!((List<?>)nodeType.getField("events").get(node)).isEmpty()) throw new AssertionError("Tackle gesture must not run bump/combat events");
        Object values=vars.getConstructor().newInstance();
        for(String name:new String[]{"PS_DefendTackle","PS_PushTackle","PS_ShoulderTackle","PS_KickGesture","Shove","BiteDefended","Stomp","","Eat"}) {
            vars.getMethod("setVariable",String.class,String.class).invoke(values,"PerformingAction",name);
            boolean selected=(Boolean)nodeType.getMethod("checkConditions",source).invoke(node,values);
            if(selected!=name.equals("PS_DefendTackle")) throw new AssertionError("Tackle action condition leaks");
        }
        Set<String> bones=new HashSet<>();
        for(Object weight:(List<?>)nodeType.getField("subStateBoneWeights").get(node)) bones.add((String)weight.getClass().getField("boneName").get(weight));
        if(!bones.equals(Set.of("Bip01_Spine"))) throw new AssertionError("Tackle must preserve pelvis/root/leg locomotion");
        String clip=Files.readString(Path.of("media/anims_X/Bob/Bob_BiteDefend.x"));
        if(!clip.contains("Frame Bip01_Spine")) throw new AssertionError("Native torso bone missing");
        var rate=java.util.regex.Pattern.compile("AnimTicksPerSecond\\s*\\{\\s*(\\d+);").matcher(clip);
        if(!rate.find()) throw new AssertionError("Missing bite-defense timing");
        var times=java.util.regex.Pattern.compile("(?m)^\\s*(\\d+);[34];").matcher(clip);
        int last=0;while(times.find()) last=Math.max(last,Integer.parseInt(times.group(1)));
        String xml=Files.readString(path);
        if(!xml.contains("<m_SpeedScale>1.40</m_SpeedScale>") || !xml.contains("<m_BlendOutTime>0.10</m_BlendOutTime>")
            || !xml.contains("<m_BlendTime>0.08</m_BlendTime>")
            || last/Double.parseDouble(rate.group(1))/1.40+0.10>41.0/30) throw new AssertionError("Tackle gesture timeout truncates clip");
        Class<?> player=Class.forName("zombie.characters.IsoPlayer");
        player.getMethod("faceLocation",float.class,float.class);
        player.getMethod("getX");player.getMethod("getY");
        System.out.println("PASS native automatic bite-defense clip, torso-only mask, event-free conditions, blends and duration; silhouette untested");
    }
    private static void verifyFall() throws Exception {
        Class<?> player=Class.forName("zombie.characters.IsoPlayer",false,MotionNativeTest.class.getClassLoader());
        for(String name:new String[]{"isLocalPlayer","isDead","getVehicle","isKnockedDown","isGettingUp","isOnFloor","getCurrentActionContextStateName","getIgnoreMovement","isSitOnGround","isSittingOnFurniture","hasHitReaction"}) player.getMethod(name);
        player.getMethod("getVariableBoolean",String.class);
        for(String name:new String[]{"setRunning","setSprinting","setMoving","setHitFromBehind","setFallOnFront","setKnockedDown"}) player.getMethod(name,boolean.class);
        Path media=Path.of("media"); // Test runner uses installed game cwd.
        String transitions=Files.readString(media.resolve("actiongroups/player/defaultTransitions.xml"));
        if(!transitions.contains("<transitionTo>knockeddown</transitionTo>") || !transitions.contains("<isTrue>bknockeddown</isTrue>")) throw new AssertionError("Knockdown graph changed");
        String recovery=Files.readString(media.resolve("actiongroups/player/knockeddown/to_getup.xml"));
        if(!recovery.contains("<transitionTo>getup</transitionTo>") || !recovery.contains("ActiveAnimFinishing") || !recovery.contains("<isFalse>bDead</isFalse>")) throw new AssertionError("Knockdown recovery changed");
        String backward=Files.readString(media.resolve("AnimSets/player/knockeddown/fallSit.xml"));
        if(!backward.contains("Bob_HitReact02_Walking") || !backward.contains("<m_Value>false</m_Value>")) throw new AssertionError("Backward reaction changed");
        try(var files=Files.list(media.resolve("AnimSets/player/knockeddown"))) {
            for(Path p:files.toList()) {
                String xml=Files.readString(p).toLowerCase();
                if(xml.contains("fallenonknees") || xml.contains("dropitem") || xml.contains("damage")) throw new AssertionError("Review knockdown side effect: "+p);
            }
        }
        System.out.println("PASS installed motion API and native knockdown/recovery graph; MP animation not proven");
    }
}
