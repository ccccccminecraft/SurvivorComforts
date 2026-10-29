import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.List;
import java.util.stream.Collectors;
import java.util.stream.Stream;

/**
 * Compiles every .lua file under the given folders with the game's own Lua
 * compiler (Kahlua, from projectzomboid.jar) and reports syntax errors.
 * Only syntax is checked; nothing is executed.
 *
 * Uses reflection so it can be compiled without the game jar on the classpath.
 */
public class LuaSyntaxCheck {
    public static void main(String[] args) throws Exception {
        Class<?> compiler = Class.forName("se.krka.kahlua.luaj.compiler.LuaCompiler");
        Class<?> tableClass = Class.forName("se.krka.kahlua.vm.KahluaTable");
        Method loadstring = compiler.getMethod("loadstring", String.class, String.class, tableClass);

        int files = 0;
        int errors = 0;
        for (String root : args) {
            List<Path> luaFiles;
            try (Stream<Path> walk = Files.walk(Paths.get(root))) {
                luaFiles = walk.filter(p -> p.toString().endsWith(".lua")).sorted().collect(Collectors.toList());
            }
            for (Path file : luaFiles) {
                files++;
                String source = new String(Files.readAllBytes(file), StandardCharsets.UTF_8);
                try {
                    loadstring.invoke(null, source, file.getFileName().toString(), null);
                    System.out.println("OK    " + file);
                } catch (InvocationTargetException e) {
                    errors++;
                    System.out.println("ERROR " + file + ": " + e.getCause());
                }
            }
        }
        System.out.println(files + " file(s), " + errors + " error(s)");
        System.exit(errors == 0 ? 0 : 1);
    }
}
