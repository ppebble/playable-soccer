import java.lang.reflect.Field;

/** Exercises installed press capture, not a running UI or multiplayer client. */
public final class InputNativeTest {
    public static void main(String[] args) throws Exception {
        Class<?> mouse=Class.forName("zombie.input.Mouse"), keyboard=Class.forName("zombie.input.GameKeyboard");
        boolean[] buttons=new boolean[10];mouse.getField("buttonDownStates").set(null,buttons);
        Field delay=mouse.getDeclaredField("timeRightPressed");
        delay.setAccessible(true);delay.setFloat(null,1f);
        buttons[1]=true;
        if(!(boolean)keyboard.getMethod("isKeyDown",int.class).invoke(null,10001)) throw new AssertionError("Baseline RMB aim binding");
        mouse.getMethod("UIBlockButtonDown",int.class).invoke(null,1);
        if((boolean)keyboard.getMethod("isKeyDown",int.class).invoke(null,10001) || !(boolean)mouse.getMethod("isButtonDown",int.class).invoke(null,1)) throw new AssertionError("Capture must suppress key binding but preserve raw charge input");
        buttons[1]=false;
        if((boolean)mouse.getMethod("isButtonDownUICheck",int.class).invoke(null,1)) throw new AssertionError("Release");
        buttons[1]=true;
        if(!(boolean)keyboard.getMethod("isKeyDown",int.class).invoke(null,10001)) throw new AssertionError("Next press must restore normal input");
        Class<?> p=Class.forName("zombie.characters.IsoPlayer",false,InputNativeTest.class.getClassLoader());
        p.getMethod("isForceAim");p.getMethod("setForceAim",boolean.class);p.getMethod("nullifyAiming");
        Class.forName("zombie.ui.UIManager",false,InputNativeTest.class.getClassLoader()).getMethod("setRightDownObject",Class.forName("zombie.iso.IsoObject",false,InputNativeTest.class.getClassLoader()));
        System.out.println("PASS installed native mouse capture, raw charge input, next-press restore and guard API; live frame timing not tested");
    }
}
