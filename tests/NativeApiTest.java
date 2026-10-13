import java.lang.reflect.*;
import java.nio.file.*;

/** Validates installed signatures and item parser, not rendered gameplay. */
public final class NativeApiTest {
    static Class<?> cls(String name) throws Exception { return Class.forName(name,false,NativeApiTest.class.getClassLoader()); }
    static int checks;
    static void method(String type,String name,Class<?>...args) throws Exception { cls(type).getMethod(name,args); checks++; }
    static String value(Object block,String key) throws Exception {
        Object v=block.getClass().getMethod("getValue",String.class).invoke(block,key);
        return ((String)v.getClass().getMethod("getValue").invoke(v)).trim();
    }
    public static void main(String[] args) throws Exception {
        String item="zombie.inventory.InventoryItem", player="zombie.characters.IsoPlayer", global="zombie.Lua.LuaManager$GlobalObject";
        Class<?> itemClass=cls(item), container=cls("zombie.inventory.ItemContainer");
        for(String name:new String[]{"getID","getFullType","getContainer","getAttachedSlot","getConditionMax","getCondition","getHaveBeenRepaired","isFavorite","hasModData","getModData","isCustomName","getName","isCustomWeight","getActualWeight"}) method(item,name);
        for(String name:new String[]{"setConditionMax","setConditionNoSound","setHaveBeenRepaired"}) method(item,name,int.class);
        for(String name:new String[]{"setFavorite","setCustomName","setCustomWeight"}) method(item,name,boolean.class);
        for(String name:new String[]{"copyTimesRepairedFrom","copyTimesHeadRepairedFrom"}) method(item,name,itemClass);
        method(item,"copyModData",cls("se.krka.kahlua.vm.KahluaTable"));
        method(item,"setActualWeight",float.class);
        method(item,"setName",String.class);
        method("zombie.inventory.ItemContainer","contains",itemClass);
        method("zombie.inventory.ItemContainer","AddItem",itemClass);
        method("zombie.inventory.ItemContainer","Remove",itemClass);
        method(global,"sendReplaceItemInContainer",container,itemClass,itemClass);
        method(global,"replaceItemInContainer",container,itemClass,itemClass);
        method(global,"sendEquip",cls(player));
        method(player,"setPrimaryHandItem",itemClass);
        method(player,"setSecondaryHandItem",itemClass);
        Class<?> square=cls("zombie.iso.IsoGridSquare");
        for(String name:new String[]{"TreatAsSolidFloor","isSolid","isSolidTrans"}) method(square.getName(),name);
        method(square.getName(),"isBlockedTo",square);
        Class<?> block=cls("zombie.scripting.ScriptParser$Block");
        Object root=cls("zombie.scripting.ScriptParser").getMethod("parse",String.class).invoke(null,Files.readString(Path.of(args[0],"media/scripts/PS_Items.txt")));
        Method getBlock=block.getMethod("getBlock",String.class,String.class);
        Object module=getBlock.invoke(root,"module","PlayableSoccer");
        Object soccer=getBlock.invoke(module,"item","SportsSoccerBall");
        if(!value(soccer,"ItemType").equals("base:normal") || !value(soccer,"WorldStaticModel").equals("SoccerBall")) throw new AssertionError("Sports ball type/model");
        checks++;
        System.out.println("PASS installed item conversion API and item parser checks="+checks);
    }
}
