import java.lang.reflect.Field;
import java.nio.file.*;

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
        for(String method:new String[]{"isPlayerMoving","isRunning","isSprinting"}) p.getMethod(method);
        Class.forName("zombie.ui.UIManager",false,InputNativeTest.class.getClassLoader()).getMethod("setRightDownObject",Class.forName("zombie.iso.IsoObject",false,InputNativeTest.class.getClassLoader()));
        System.out.println("PASS installed native mouse capture, raw charge input, next-press restore and guard API; live frame timing not tested");
        checkInstalledLuaPanel(Path.of(args[0]));
    }
    static void checkInstalledLuaPanel(Path mod) throws Exception {
        // Verify the real Lua method surface, not a mock inventing Java wrappers.
        Class<?> nativeUI=Class.forName("zombie.ui.UIElement",false,InputNativeTest.class.getClassLoader());
        for(String method:new String[]{"onConsumeKeyPress","onConsumeKeyRepeat","onConsumeKeyRelease","isKeyConsumed"}) nativeUI.getMethod(method,int.class);
        for(String method:new String[]{"setX","setY","setWidth","setHeight"}) nativeUI.getMethod(method,double.class);
        for(String method:new String[]{"setAnchorLeft","setAnchorRight","setAnchorTop","setAnchorBottom","setWantKeyEvents","setConsumeMouseEvents","setWantExtraMouseEvents","setForceCursorVisible"}) nativeUI.getMethod(method,boolean.class);
        Path bootstrap=Files.createTempFile("ps-ui-native-",".lua"), assertion=Files.createTempFile("ps-ui-assert-",".lua");
        try {
            Files.writeString(bootstrap,"""
                ISDock={None=0};UIHorizontalAlignment={Left=0}
                function getISUIStackTrace() return '' end
                UIElement={new=function(table)
                    local java={}
                    for _,name in ipairs({'setX','setY','setWidth','setHeight','setAnchorLeft','setAnchorRight','setAnchorTop','setAnchorBottom','setWantKeyEvents','setWantExtraMouseEvents','setForceCursorVisible'}) do
                        java[name]=function(self,value) self[name..'Value']=value end
                    end
                    java.setConsumeMouseEvents=function(self,value) self.consume=value end
                    return java
                end}
                UIManager.AddUI=function(ui) TEST.registered=TEST.registered+1 end
                UIManager.RemoveElement=function(ui) end
                PSRender={clear=function() end}
                """);
            Files.writeString(assertion,"""
                assert(ISPanel.setConsumeMouseEvents==nil, 'Expected Java-only method; do not invent Lua wrapper')
                Events.OnGameStart.callback()
                assert(TEST.registered==1)
                assert(PSClient.overlay.javaObject.consume==false)
                assert(PSClient.overlay.width==1280 and PSClient.overlay.height==720)
                assert(TEST.sent[#TEST.sent].command=='sync')
                TEST.width=1600;TEST.height=900;PSClient.overlay:render()
                assert(PSClient.overlay.width==1600 and PSClient.overlay.height==900)
                assert(TEST.hudRendered)
                local ui=PSClient.overlay
                local rects={}
                ui.drawRect=function(self,x,y,w,h) rects[#rects+1]={x=x,w=w,h=h} end
                ui:drawProgressBar(10,20,300,18,.5,{a=1,r=1,g=1,b=1})
                assert(#rects==2 and rects[1].w==150 and rects[2].x==160 and rects[2].w==150)
                assert(ui.javaObject.setWantKeyEventsValue==true)
                local esc=Keyboard.KEY_ESCAPE
                PSClient.selected=1
                ui:onKeyPress(esc);assert(ui:isKeyConsumed(esc))
                ui:onKeyRelease(esc)
                assert(PSClient.selected==nil and ui:isKeyConsumed(esc), 'Exit press must not open vanilla menu')
                ui:onKeyPress(esc);ui:onKeyRelease(esc)
                assert(not ui:isKeyConsumed(esc), 'Next Escape returns to vanilla menu')
                PSClient.selected=1;PSClient.charge={}
                ui:onKeyPress(esc);ui:onKeyRelease(esc)
                assert(PSClient.charge==nil and PSClient.selected==1 and ui:isKeyConsumed(esc))
                ui:onKeyPress(17);ui:onKeyRelease(17)
                assert(not ui:isKeyConsumed(17) and PSClient.selected==1)
                TEST.setup=true
                ui:onKeyPress(esc);ui:onKeyRelease(esc)
                assert(not TEST.setup and ui:isKeyConsumed(esc))
                TEST.paused=true
                ui:onKeyPress(esc);ui:onKeyRelease(esc)
                assert(not ui:isKeyConsumed(esc) and PSClient.selected==1)
                TEST.paused=false;TEST.typing=true
                ui:onKeyPress(esc);ui:onKeyRelease(esc)
                assert(not ui:isKeyConsumed(esc))
                TEST.typing=false;TEST.dead=true
                ui:onKeyPress(esc);ui:onKeyRelease(esc)
                assert(not ui:isKeyConsumed(esc))
                """);
            Path repo=mod.toAbsolutePath().getParent().getParent().getParent().getParent();
            LuaHarness.main(new String[]{repo.resolve("tests/client-bootstrap.lua").toString(),bootstrap.toString(),
                "media/lua/shared/ISBaseObject.lua","media/lua/client/ISUI/ISUIElement.lua","media/lua/client/ISUI/ISPanel.lua",
                mod.resolve("media/lua/client/PS_Client.lua").toString(),assertion.toString()});
            System.out.println("PASS installed Lua ISPanel/ISUIElement production HUD startup, no nonexistent Java-only wrapper, resize and click-through contract; native UI stubbed");
        } finally {Files.deleteIfExists(bootstrap);Files.deleteIfExists(assertion);}
    }
}
