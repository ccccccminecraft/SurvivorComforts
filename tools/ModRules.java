import java.lang.reflect.Method;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeSet;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Collectors;
import java.util.stream.Stream;

/**
 * Checks the mod for mistakes the Lua compiler does not catch:
 *
 *   - translation keys: every Translate/<language>/UI.json has the same keys,
 *     no key twice, and every "UI_SurvivorComforts_..." key the code uses is
 *     there. Keys no code uses are only warned about; a key built from parts
 *     ("UI_SurvivorComforts_" .. id .. "_Key") counts as used when its last
 *     part ("_Key") is in the code.
 *   - functions of standard Lua 5.1 that the game's Lua (Kahlua) does not
 *     have (next, xpcall, math.random, io, ...). What Kahlua has is read from
 *     the game every time, so this follows game updates. Comments and strings
 *     are not looked at.
 *
 * Run from the game folder (Kahlua reads stdlib.lua from the working
 * directory), with the mod folder as the argument. Uses reflection so it can
 * be compiled without the game jar on the classpath.
 */
public class ModRules {
    private static final String KEY_PREFIX = "UI_SurvivorComforts_";

    private static final List<String> STANDARD_GLOBALS = Arrays.asList(
        "assert", "collectgarbage", "dofile", "error", "gcinfo", "getfenv", "getmetatable", "ipairs",
        "load", "loadfile", "loadstring", "module", "newproxy", "next", "pairs", "pcall", "print",
        "rawequal", "rawget", "rawset", "require", "select", "setfenv", "setmetatable", "tonumber",
        "tostring", "type", "unpack", "xpcall");

    private static final Map<String, List<String>> STANDARD_LIBRARIES = new LinkedHashMap<>();
    static {
        STANDARD_LIBRARIES.put("string", Arrays.asList("byte", "char", "dump", "find", "format", "gfind",
            "gmatch", "gsub", "len", "lower", "match", "rep", "reverse", "sub", "upper"));
        STANDARD_LIBRARIES.put("table", Arrays.asList("concat", "foreach", "foreachi", "getn", "insert",
            "maxn", "remove", "setn", "sort"));
        STANDARD_LIBRARIES.put("math", Arrays.asList("abs", "acos", "asin", "atan", "atan2", "ceil", "cos",
            "cosh", "deg", "exp", "floor", "fmod", "frexp", "huge", "ldexp", "log", "log10", "max", "min",
            "mod", "modf", "pi", "pow", "rad", "random", "randomseed", "sin", "sinh", "sqrt", "tan", "tanh"));
        STANDARD_LIBRARIES.put("os", Arrays.asList("clock", "date", "difftime", "execute", "exit", "getenv",
            "remove", "rename", "setlocale", "time", "tmpname"));
        STANDARD_LIBRARIES.put("coroutine", Arrays.asList("create", "resume", "running", "status", "wrap", "yield"));
        STANDARD_LIBRARIES.put("io", Arrays.asList());
        STANDARD_LIBRARIES.put("debug", Arrays.asList());
        STANDARD_LIBRARIES.put("package", Arrays.asList());
    }

    // Not in Kahlua's own library, but the game adds it.
    private static final Set<String> GAME_PROVIDES = new HashSet<>(Arrays.asList("require"));

    private static final Pattern JSON_KEY = Pattern.compile("^\\s*\"([^\"]+)\"\\s*:");
    private static final Pattern CODE_KEY = Pattern.compile("\"(" + KEY_PREFIX + "[A-Za-z0-9_]+)\"");
    private static final Pattern KEY_PART = Pattern.compile("\"(_[A-Za-z0-9_]+)\"");

    private static int errors = 0;
    private static int warnings = 0;

    public static void main(String[] args) throws Exception {
        Path root = Paths.get(args[0]).toAbsolutePath().normalize();
        List<Path> files;
        try (Stream<Path> walk = Files.walk(root)) {
            files = walk.filter(Files::isRegularFile).sorted().collect(Collectors.toList());
        }
        List<Path> luaFiles = files.stream().filter(p -> p.toString().endsWith(".lua")).collect(Collectors.toList());
        List<Path> translations = files.stream()
            .filter(p -> p.getFileName().toString().equals("UI.json") && p.getParent().getParent().getFileName().toString().equals("Translate"))
            .collect(Collectors.toList());

        Map<Path, String> withStrings = new LinkedHashMap<>();
        Map<Path, String> codeOnly = new LinkedHashMap<>();
        for (Path file : luaFiles) {
            String source = new String(Files.readAllBytes(file), StandardCharsets.UTF_8);
            withStrings.put(file, blank(source, true));
            codeOnly.put(file, blank(source, false));
        }

        checkTranslations(root, translations, withStrings);
        checkFunctions(root, codeOnly);

        System.out.println("rules: " + errors + " error(s), " + warnings + " warning(s)");
        System.exit(errors == 0 ? 0 : 1);
    }

    private static void error(String message) {
        errors++;
        System.out.println("ERROR " + message);
    }

    private static void warn(String message) {
        warnings++;
        System.out.println("WARN  " + message);
    }

    // ------------------------------------------------------------------
    // Translation keys
    // ------------------------------------------------------------------
    private static void checkTranslations(Path root, List<Path> translations, Map<Path, String> sources) throws Exception {
        if (translations.isEmpty()) {
            error("no Translate/<language>/UI.json found");
            return;
        }
        Map<Path, Set<String>> keysByFile = new LinkedHashMap<>();
        Set<String> allKeys = new TreeSet<>();
        for (Path file : translations) {
            Set<String> keys = new HashSet<>();
            List<String> lines = Files.readAllLines(file, StandardCharsets.UTF_8);
            for (int i = 0; i < lines.size(); i++) {
                Matcher m = JSON_KEY.matcher(lines.get(i));
                if (m.find() && !keys.add(m.group(1))) {
                    error(root.relativize(file) + ":" + (i + 1) + ": " + m.group(1) + " is written twice");
                }
            }
            keysByFile.put(file, keys);
            allKeys.addAll(keys);
        }
        for (Map.Entry<Path, Set<String>> entry : keysByFile.entrySet()) {
            for (String key : allKeys) {
                if (!entry.getValue().contains(key)) {
                    error(root.relativize(entry.getKey()) + ": " + key + " is missing (other languages have it)");
                }
            }
        }

        Set<String> used = new HashSet<>();
        Set<String> parts = new HashSet<>();
        boolean buildsKeys = false;
        for (Map.Entry<Path, String> entry : sources.entrySet()) {
            String source = entry.getValue();
            Matcher m = CODE_KEY.matcher(source);
            while (m.find()) {
                String key = m.group(1);
                used.add(key);
                if (!allKeys.contains(key)) {
                    error(root.relativize(entry.getKey()) + ":" + lineOf(source, m.start()) + ": " + key + " is not in UI.json");
                }
            }
            Matcher p = KEY_PART.matcher(source);
            while (p.find()) parts.add(p.group(1));
            if (source.contains("\"" + KEY_PREFIX + "\"")) buildsKeys = true;
        }
        for (String key : allKeys) {
            if (used.contains(key)) continue;
            boolean built = false;
            if (buildsKeys && key.startsWith(KEY_PREFIX)) {
                for (String part : parts) {
                    if (key.endsWith(part)) { built = true; break; }
                }
            }
            if (!built) warn(key + " is not used by any code");
        }
    }

    // ------------------------------------------------------------------
    // Functions the game's Lua does not have
    // ------------------------------------------------------------------
    private static void checkFunctions(Path root, Map<Path, String> sources) throws Exception {
        Set<String> available = kahluaNames();
        List<String> missingGlobals = new ArrayList<>();
        for (String name : STANDARD_GLOBALS) {
            if (!available.contains(name) && !GAME_PROVIDES.contains(name)) missingGlobals.add(name);
        }
        List<String> missingLibraries = new ArrayList<>();
        List<String> missingMembers = new ArrayList<>();
        for (Map.Entry<String, List<String>> lib : STANDARD_LIBRARIES.entrySet()) {
            if (!available.contains(lib.getKey())) {
                missingLibraries.add(lib.getKey());
                continue;
            }
            for (String member : lib.getValue()) {
                String name = lib.getKey() + "." + member;
                if (!available.contains(name)) missingMembers.add(name);
            }
        }

        List<Pattern> patterns = new ArrayList<>();
        List<String> names = new ArrayList<>();
        for (String name : missingGlobals) {
            // Not a field (x.next), a definition (local next / function next) or a table key (next = 1).
            patterns.add(Pattern.compile("(?<![\\w.:])(?<!local\\s)(?<!function\\s)" + name + "\\b(?!\\s*=[^=])"));
            names.add(name);
        }
        for (String name : missingMembers) {
            String[] split = name.split("\\.");
            patterns.add(Pattern.compile("(?<![\\w.:])" + split[0] + "\\s*\\.\\s*" + split[1] + "\\b(?!\\s*=[^=])"));
            names.add(name);
        }
        for (String lib : missingLibraries) {
            patterns.add(Pattern.compile("(?<![\\w.:])" + lib + "\\s*[.:]"));
            names.add(lib);
        }

        for (Map.Entry<Path, String> entry : sources.entrySet()) {
            String source = entry.getValue();
            Set<String> locals = localNames(source);
            for (int i = 0; i < patterns.size(); i++) {
                // A local of the same name (local function load, function(module)) is the file's own.
                if (locals.contains(names.get(i))) continue;
                Matcher m = patterns.get(i).matcher(source);
                while (m.find()) {
                    error(root.relativize(entry.getKey()) + ":" + lineOf(source, m.start()) + ": "
                        + names.get(i) + " is not in the game's Lua (Kahlua)");
                }
            }
        }
    }

    private static final Pattern LOCAL_FUNCTION = Pattern.compile("\\blocal\\s+function\\s+(\\w+)");
    private static final Pattern LOCAL_NAMES = Pattern.compile("\\blocal\\s+(?!function\\b)(\\w+(?:\\s*,\\s*\\w+)*)");
    private static final Pattern PARAMETERS = Pattern.compile("\\bfunction\\b[\\w\\s.:]*\\(([^)]*)\\)");
    private static final Pattern LOOP_NAMES = Pattern.compile("\\bfor\\s+(\\w+(?:\\s*,\\s*\\w+)*)\\s*(?:=|\\bin\\b)");

    // Every name a file declares as a local, a function parameter or a loop variable.
    private static Set<String> localNames(String source) {
        Set<String> names = new HashSet<>();
        Matcher m = LOCAL_FUNCTION.matcher(source);
        while (m.find()) names.add(m.group(1));
        for (Pattern list : Arrays.asList(LOCAL_NAMES, PARAMETERS, LOOP_NAMES)) {
            m = list.matcher(source);
            while (m.find()) {
                for (String name : m.group(1).split(",")) {
                    if (!name.trim().isEmpty()) names.add(name.trim());
                }
            }
        }
        return names;
    }

    // Names in Kahlua's standard environment: "next", "string", "string.find", ...
    private static Set<String> kahluaNames() throws Exception {
        Class<?> platform = Class.forName("se.krka.kahlua.j2se.J2SEPlatform");
        Class<?> tableClass = Class.forName("se.krka.kahlua.vm.KahluaTable");
        Class<?> iteratorClass = Class.forName("se.krka.kahlua.vm.KahluaTableIterator");
        Method iterator = tableClass.getMethod("iterator");
        Method advance = iteratorClass.getMethod("advance");
        Method getKey = iteratorClass.getMethod("getKey");
        Method getValue = iteratorClass.getMethod("getValue");

        Object env = platform.getMethod("newEnvironment").invoke(platform.getMethod("getInstance").invoke(null));
        Set<String> names = new HashSet<>();
        Object it = iterator.invoke(env);
        while ((Boolean) advance.invoke(it)) {
            Object key = getKey.invoke(it);
            Object value = getValue.invoke(it);
            if (!(key instanceof String)) continue;
            names.add((String) key);
            if (STANDARD_LIBRARIES.containsKey(key) && tableClass.isInstance(value)) {
                Object libIt = iterator.invoke(value);
                while ((Boolean) advance.invoke(libIt)) {
                    Object member = getKey.invoke(libIt);
                    if (member instanceof String) names.add(key + "." + member);
                }
            }
        }
        return names;
    }

    // ------------------------------------------------------------------
    // Source helpers
    // ------------------------------------------------------------------
    private static int lineOf(String source, int index) {
        int line = 1;
        for (int i = 0; i < index; i++) {
            if (source.charAt(i) == '\n') line++;
        }
        return line;
    }

    // Level of a long bracket starting at i ("[[" = 0, "[==[" = 2), or -1.
    private static int longBracket(String s, int i) {
        if (i >= s.length() || s.charAt(i) != '[') return -1;
        int j = i + 1;
        while (j < s.length() && s.charAt(j) == '=') j++;
        return j < s.length() && s.charAt(j) == '[' ? j - i - 1 : -1;
    }

    // The source with comments (and, unless keepStrings, the inside of
    // strings) replaced by spaces. Line breaks are kept, so line numbers stay.
    private static String blank(String s, boolean keepStrings) {
        StringBuilder out = new StringBuilder(s.length());
        int i = 0;
        int n = s.length();
        while (i < n) {
            char c = s.charAt(i);
            if (c == '-' && i + 1 < n && s.charAt(i + 1) == '-') {
                int level = longBracket(s, i + 2);
                int end;
                if (level >= 0) {
                    String close = "]" + "=".repeat(level) + "]";
                    int found = s.indexOf(close, i);
                    end = found < 0 ? n : found + close.length();
                } else {
                    int found = s.indexOf('\n', i);
                    end = found < 0 ? n : found;
                }
                spaces(out, s, i, end);
                i = end;
            } else if (c == '"' || c == '\'') {
                int j = i + 1;
                while (j < n && s.charAt(j) != c && s.charAt(j) != '\n') {
                    if (s.charAt(j) == '\\') j++;
                    j++;
                }
                int end = Math.min(j + 1, n);
                if (keepStrings) out.append(s, i, end); else { out.append(c); spaces(out, s, i + 1, end - 1); out.append(c); }
                i = end;
            } else if (longBracket(s, i) >= 0) {
                int level = longBracket(s, i);
                String close = "]" + "=".repeat(level) + "]";
                int found = s.indexOf(close, i);
                int end = found < 0 ? n : found + close.length();
                if (keepStrings) out.append(s, i, end); else spaces(out, s, i, end);
                i = end;
            } else {
                out.append(c);
                i++;
            }
        }
        return out.toString();
    }

    private static void spaces(StringBuilder out, String s, int from, int to) {
        for (int k = from; k < to && k < s.length(); k++) {
            out.append(s.charAt(k) == '\n' ? '\n' : ' ');
        }
    }
}
