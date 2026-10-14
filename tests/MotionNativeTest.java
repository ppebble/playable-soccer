import java.nio.file.*;
import java.util.*;

/** Installed native contracts, not rendered motion or multiplayer evidence. */
public final class MotionNativeTest {
    public static void main(String[] args) throws Exception {
        verifyFall();
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
        for(String name:new String[]{"PS_StrongKickGesture","PS_KickGesture","PS_ShoulderTackle","Stomp","","Eat"}) {
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
    private static void verifyTackle(String mod) throws Exception {
        Class<?> nodeType=Class.forName("zombie.core.skinnedmodel.advancedanimation.AnimNode");
        Class<?> vars=Class.forName("zombie.core.skinnedmodel.advancedanimation.AnimationVariableSource");
        Class<?> source=Class.forName("zombie.core.skinnedmodel.advancedanimation.IAnimationVariableSource");
        Path path=Path.of(mod,"media/AnimSets/player/actions/PS_ShoulderTackle.xml");
        Object node=nodeType.getMethod("Parse",String.class).invoke(null,path.toString());
        if(node==null || !"Bob_IdleToSprint".equals(nodeType.getField("animName").get(node))) throw new AssertionError("Native forward acceleration clip required");
        if(nodeType.getField("useDeferredMovement").getBoolean(node) || nodeType.getField("deferredRotationScale").getFloat(node)!=0) throw new AssertionError("Tackle cannot drive root motion/turning");
        if(!((List<?>)nodeType.getField("events").get(node)).isEmpty()) throw new AssertionError("Tackle gesture must not run bump/combat events");
        Object values=vars.getConstructor().newInstance();
        for(String name:new String[]{"PS_ShoulderTackle","PS_KickGesture","Shove","Stomp","","Eat"}) {
            vars.getMethod("setVariable",String.class,String.class).invoke(values,"PerformingAction",name);
            boolean selected=(Boolean)nodeType.getMethod("checkConditions",source).invoke(node,values);
            if(selected!=name.equals("PS_ShoulderTackle")) throw new AssertionError("Tackle action condition leaks");
        }
        Set<String> bones=new HashSet<>();
        for(Object weight:(List<?>)nodeType.getField("subStateBoneWeights").get(node)) bones.add((String)weight.getClass().getField("boneName").get(weight));
        if(!bones.equals(Set.of("Bip01_Spine"))) throw new AssertionError("Tackle must preserve pelvis/root/leg locomotion");
        String clip=Files.readString(Path.of("media/anims_X/Bob/Bob_IdleToSprint.x"));
        if(!clip.contains("Frame Bip01_Spine")) throw new AssertionError("Native torso bone missing");
        var rate=java.util.regex.Pattern.compile("AnimTicksPerSecond\\s*\\{\\s*(\\d+);").matcher(clip);
        if(!rate.find()) throw new AssertionError("Missing bump timing");
        var times=java.util.regex.Pattern.compile("(?m)^\\s*(\\d+);[34];").matcher(clip);
        int last=0;while(times.find()) last=Math.max(last,Integer.parseInt(times.group(1)));
        String xml=Files.readString(path);
        if(!xml.contains("<m_SpeedScale>2.2</m_SpeedScale>") || !xml.contains("<m_BlendOutTime>0.14</m_BlendOutTime>")
            || !xml.contains("<m_BlendTime>0.12</m_BlendTime>")
            || last/Double.parseDouble(rate.group(1))/2.2+0.14>18.0/30) throw new AssertionError("Tackle gesture timeout truncates clip");
        Class<?> player=Class.forName("zombie.characters.IsoPlayer");
        player.getMethod("faceLocation",float.class,float.class);
        player.getMethod("getX");player.getMethod("getY");
        System.out.println("PASS native sprint-start lean, torso-only mask, event-free conditions, softer blends and duration; silhouette untested");
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
