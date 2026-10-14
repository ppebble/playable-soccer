import java.nio.file.*;
import java.util.*;

/** Installed native contracts, not rendered motion or multiplayer evidence. */
public final class MotionNativeTest {
    public static void main(String[] args) throws Exception {
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
}
