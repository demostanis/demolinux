import { tool } from "@opencode-ai/plugin";
import { spawn } from "child_process";

const DEFAULT_TIMEOUT = 2 * 60 * 1000;

export default tool({
  description: "Execute Python code using uv with optional package dependencies installed via uv --with.",
  args: {
    code: tool.schema.string().describe("The Python code to execute"),
    packages: tool.schema.array(tool.schema.string()).default([]).describe("List of packages to install via uv --with (e.g., ['requests', 'numpy'])"),
    timeout: tool.schema.number().optional().describe("Optional timeout in milliseconds"),
    description: tool.schema.string().describe("Clear, concise description of what this code does in 5-10 words"),
  },
  async execute(params, ctx) {
    const timeout = params.timeout ?? DEFAULT_TIMEOUT;
    const cwd = ctx.directory;

    const uvArgs = ["run"];
    for (const pkg of params.packages) {
      uvArgs.push("--with", pkg);
    }
    uvArgs.push("python", "-c", params.code);

    // Check for file operations
    const patterns = new Set<string>();
    const fileRegexes = [
      /open\s*\(\s*['"]([^'"]+)['"]/g,
      /with\s+open\s*\(\s*['"]([^'"]+)['"]/g,
    ];
    
    for (const regex of fileRegexes) {
      const matches = params.code.matchAll(regex);
      for (const match of matches) {
        const path = match[1];
        if (path && !path.startsWith("/")) {
          patterns.add(`${cwd}/${path}`);
        } else if (path) {
          patterns.add(path);
        }
      }
    }

    if (patterns.size > 0) {
      await ctx.ask({
        permission: "external_directory",
        patterns: Array.from(patterns),
        always: Array.from(patterns),
        metadata: {},
      });
    }

    await ctx.ask({
      permission: "python",
      patterns: [params.description],
      always: ["python *"],
      metadata: { code: params.code, packages: params.packages },
    });

    const displayCmd = `uv ${uvArgs.map(arg => arg.includes(" ") ? `"${arg}"` : arg).join(" ")}`;

    return new Promise((resolve, reject) => {
      const proc = spawn("uv", uvArgs, {
        cwd,
        stdio: ["ignore", "pipe", "pipe"],
        detached: process.platform !== "win32",
      });

      let output = "";

      proc.stdout?.on("data", (chunk) => {
        output += chunk.toString();
      });

      proc.stderr?.on("data", (chunk) => {
        output += chunk.toString();
      });

      let timedOut = false;
      let aborted = false;
      let exited = false;

      const kill = () => {
        if (!exited && proc.pid) {
          try {
            process.kill(-proc.pid, "SIGTERM");
          } catch {
            proc.kill("SIGTERM");
          }
        }
      };

      if (ctx.abort.aborted) {
        aborted = true;
        kill();
      }

      const abortHandler = () => {
        aborted = true;
        kill();
      };

      ctx.abort.addEventListener("abort", abortHandler, { once: true });

      const timeoutTimer = setTimeout(() => {
        timedOut = true;
        kill();
      }, timeout + 100);

      proc.once("exit", (code) => {
        exited = true;
        clearTimeout(timeoutTimer);
        ctx.abort.removeEventListener("abort", abortHandler);

        let result = output;
        if (timedOut) result += `\n\n[timeout after ${timeout}ms]`;
        if (aborted) result += `\n\n[aborted by user]`;

        const formattedOutput = `Code:\n${params.code}\n\nPackages: ${params.packages.length > 0 ? params.packages.join(", ") : "none"}\n\nCommand: ${displayCmd}\n\nOutput:\n${result}`;

        resolve(formattedOutput);
      });

      proc.once("error", reject);
    });
  },
});
