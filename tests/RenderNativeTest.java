/** Signature checks against the installed game; no graphics context is created. */
public final class RenderNativeTest {
    public static void main(String[] args) throws Exception {
        Class<?> item=Class.forName("zombie.inventory.InventoryItem",false,RenderNativeTest.class.getClassLoader());
        Class<?> square=Class.forName("zombie.iso.IsoGridSquare",false,RenderNativeTest.class.getClassLoader());
        Class<?> proxy=Class.forName("zombie.iso.objects.IsoWorldInventoryObject",false,RenderNativeTest.class.getClassLoader());
        Class<?> color=Class.forName("zombie.core.textures.ColorInfo",false,RenderNativeTest.class.getClassLoader());
        Class<?> shader=Class.forName("zombie.core.opengl.Shader",false,RenderNativeTest.class.getClassLoader());
        proxy.getConstructor(item,square,float.class,float.class,float.class);
        proxy.getMethod("setSquare",square);
        Class<?> sprite=Class.forName("zombie.iso.sprite.IsoSprite",false,RenderNativeTest.class.getClassLoader());
        sprite.getConstructor();proxy.getMethod("setSprite",sprite);
        for(String method:new String[]{"setOffX","setOffY","setOffZ"}) proxy.getMethod(method,float.class);
        proxy.getMethod("setAlphaAndTarget",int.class,float.class);
        proxy.getMethod("render",float.class,float.class,float.class,color,boolean.class,boolean.class,shader);
        square.getMethod("isCanSee",int.class);
        color.getConstructor(float.class,float.class,float.class,float.class);
        Class.forName("zombie.core.Core",false,RenderNativeTest.class.getClassLoader()).getMethod("isOption3DGroundItem");
        System.out.println("PASS installed native detached-render signatures; visual behavior not tested");
    }
}
