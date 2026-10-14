import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.nio.file.*;
import java.util.Arrays;

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
                assert(PSClient.overlay.width==0 and PSClient.overlay.height==0)
                assert(TEST.sent[#TEST.sent].command=='sync')
                TEST.width=1600;TEST.height=900;PSClient.overlay:render()
                assert(PSClient.overlay.width==0 and PSClient.overlay.height==0)
                assert(TEST.hudRendered)
                local ui=PSClient.overlay
                local rects={}
                ui.drawRect=function(self,x,y,w,h) rects[#rects+1]={x=x,w=w,h=h} end
                ui:drawProgressBar(10,20,300,18,.5,{a=1,r=1,g=1,b=1})
                assert(#rects==2 and rects[1].w==150 and rects[2].x==160 and rects[2].w==150)
                assert(ui.javaObject.setWantKeyEventsValue==true)
                local esc=Keyboard.KEY_ESCAPE
                PSClient.state={balls={{id=1,owner='test',x=1,y=1,z=0,h=0}}}
                PSClient.selected=1
                ui:onKeyPress(esc);assert(ui:isKeyConsumed(esc))
                ui:onKeyRelease(esc)
                assert(PSClient.selected==1 and PSClient.menu and ui:isKeyConsumed(esc), 'Soccer menu press must not open vanilla menu')
                ui:onKeyPress(esc);ui:onKeyRelease(esc)
                assert(PSClient.selected==1 and not PSClient.menu and ui:isKeyConsumed(esc), 'Next Escape closes soccer menu')
                PSClient.leave();ui:onKeyPress(esc);ui:onKeyRelease(esc)
                assert(not ui:isKeyConsumed(esc), 'Escape outside soccer returns to vanilla menu')
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
                -- A real vanilla panel's empty callbacks return nil, which the
                -- native dispatch treats as consumption even with consume=false.
                PSNativeBaseline=ISPanel:new(0,0,1600,900)
                PSNativeBaseline:initialise();PSNativeBaseline:setWantMouseEvents(false)
                assert(PSNativeBaseline:onMouseUp(10,10)==nil)
                assert(PSNativeBaseline:onRightMouseDown(10,10)==nil)
                assert(PSNativeBaseline:onRightMouseUp(10,10)==nil)
                for _,selected in ipairs({false,1}) do
                    PSClient.selected=selected or nil
                    for _,name in ipairs({'onMouseDown','onMouseUp','onRightMouseDown','onRightMouseUp','onMouseMove','onMouseWheel'}) do
                        assert(ui[name](ui,10,10)==false, name..' must explicitly return false before and during soccer')
                    end
                end
                PSClient.selected=nil
                PSNativeOverlay=ui
                """);
            Path repo=mod.toAbsolutePath().getParent().getParent().getParent().getParent();
            Object env=runNativeEnvironment(new String[]{repo.resolve("tests/client-bootstrap.lua").toString(),bootstrap.toString(),
                "media/lua/shared/ISBaseObject.lua","media/lua/client/ISUI/ISUIElement.lua","media/lua/client/ISUI/ISPanel.lua",
                mod.resolve("media/lua/client/PS_Client.lua").toString(),assertion.toString()});
            checkNativeDispatch(nativeUI,env);
            System.out.println("PASS installed Lua HUD startup and actual native mouse dispatch/hit-test: baseline consumes RMB, zero-area production overlay passes buttons and inventory hit-testing; rendering stubbed, not live gameplay");
        } finally {Files.deleteIfExists(bootstrap);Files.deleteIfExists(assertion);}
    }
    static Object runNativeEnvironment(String[] files) throws Exception {
        Class<?> table=Class.forName("se.krka.kahlua.vm.KahluaTable"), platformType=Class.forName("se.krka.kahlua.vm.Platform");
        Class<?> platformClass=Class.forName("se.krka.kahlua.j2se.J2SEPlatform");
        Object platform=platformClass.getMethod("getInstance").invoke(null);
        Object env=platformClass.getMethod("newEnvironment").invoke(platform);
        Class<?> threadType=Class.forName("se.krka.kahlua.vm.KahluaThread");
        Object thread=threadType.getConstructor(platformType,table).newInstance(platform,env);
        threadType.getField("debugOwnerThread").set(thread,Thread.currentThread());
        Class<?> manager=Class.forName("zombie.Lua.LuaManager");
        manager.getField("thread").set(null,thread);manager.getField("env").set(null,env);
        Class<?> converters=Class.forName("se.krka.kahlua.converter.KahluaConverterManager");
        Object caller=Class.forName("se.krka.kahlua.integration.LuaCaller").getConstructor(converters).newInstance(converters.getConstructor().newInstance());
        manager.getField("caller").set(null,caller);
        Method compile=Class.forName("se.krka.kahlua.luaj.compiler.LuaCompiler").getMethod("loadstring",String.class,String.class,table);
        Method run=threadType.getMethod("pcall",Object.class,Object[].class);
        for(String file:files) {
            Object chunk=compile.invoke(null,Files.readString(Path.of(file)),file,env);
            Object[] result=(Object[])run.invoke(thread,chunk,new Object[0]);
            if(!Boolean.TRUE.equals(result[0])) throw new AssertionError(file+": "+Arrays.toString(result));
        }
        return env;
    }
    static void checkNativeDispatch(Class<?> nativeUI,Object env) throws Exception {
        Class<?> table=Class.forName("se.krka.kahlua.vm.KahluaTable");
        Method get=table.getMethod("rawget",Object.class);
        Object baseline=nativeUI.getConstructor(table).newInstance(get.invoke(env,"PSNativeBaseline"));
        Object overlay=nativeUI.getConstructor(table).newInstance(get.invoke(env,"PSNativeOverlay"));
        for(Object ui:new Object[]{baseline,overlay}) {
            nativeUI.getMethod("setWidth",double.class).invoke(ui,1600d);
            nativeUI.getMethod("setHeight",double.class).invoke(ui,900d);
            nativeUI.getMethod("setConsumeMouseEvents",boolean.class).invoke(ui,false);
        }
        Method down=nativeUI.getMethod("onConsumeMouseButtonDown",int.class,double.class,double.class);
        Method up=nativeUI.getMethod("onConsumeMouseButtonUp",int.class,double.class,double.class);
        boolean baselineRightDown=(boolean)down.invoke(baseline,1,10d,10d),baselineRightUp=(boolean)up.invoke(baseline,1,10d,10d),baselineLeftUp=(boolean)up.invoke(baseline,0,10d,10d);
        if(!baselineRightDown || !baselineRightUp || baselineLeftUp)
            throw new AssertionError("Installed native dispatch must reproduce inherited nil-callback capture: "+baselineRightDown+","+baselineRightUp+","+baselineLeftUp);
        for(int button:new int[]{0,1}) {
            if((boolean)down.invoke(overlay,button,10d,10d) || (boolean)up.invoke(overlay,button,10d,10d))
                throw new AssertionError("HUD swallowed world button "+button);
        }
        Method hit=nativeUI.getMethod("isPointOver",double.class,double.class);
        if(!(boolean)hit.invoke(baseline,100d,100d)) throw new AssertionError("Fullscreen baseline must obstruct inventory world drop despite consume=false");
        nativeUI.getMethod("setWidth",double.class).invoke(overlay,0d);
        nativeUI.getMethod("setHeight",double.class).invoke(overlay,0d);
        for(double[] point:new double[][]{{0,0},{100,100},{1599,899}}) {
            if((boolean)hit.invoke(overlay,point[0],point[1])) throw new AssertionError("Zero-area HUD obstructed world/inventory hit-test");
        }
    }
}
