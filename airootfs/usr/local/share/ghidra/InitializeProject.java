import ghidra.app.script.GhidraScript;

// A headless script allows creating an empty project without importing a binary.
public class InitializeProject extends GhidraScript {
    @Override
    public void run() throws Exception {
        state.getProject().save();
    }
}
