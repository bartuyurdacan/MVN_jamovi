#!/usr/bin/env python3
"""
MVN Jamovi Module Builder
=========================
Builds MVN.jmo for any jamovi version by using that version's R.

Usage:
    python build_jmo.py "C:/Program Files/jamovi 2.6.19.0"
    python build_jmo.py "C:/Program Files/jamovi 2.5.6.0"

The script will:
1. Detect the R version bundled with jamovi
2. Install MVN package from source using that R
3. Install all dependencies as binaries
4. Generate the .jmo file with correct metadata
"""

import sys
import os
import subprocess
import shutil
import zipfile
import tempfile
import re

def find_r(jamovi_path):
    """Find R executables in jamovi installation."""
    r_bin = os.path.join(jamovi_path, "Frameworks", "R", "bin", "x64")
    rscript = os.path.join(r_bin, "Rscript.exe")
    rcmd = os.path.join(r_bin, "Rcmd.exe")
    if not os.path.exists(rscript):
        # Try without x64 for older versions
        r_bin = os.path.join(jamovi_path, "Frameworks", "R", "bin")
        rscript = os.path.join(r_bin, "Rscript.exe")
        rcmd = os.path.join(r_bin, "Rcmd.exe")
    if not os.path.exists(rscript):
        print(f"ERROR: Rscript.exe not found in {jamovi_path}")
        sys.exit(1)
    return rscript, rcmd

def get_r_version(rscript):
    """Get R version string."""
    result = subprocess.run(
        [rscript, "-e", 'cat(R.version$major, ".", R.version$minor, sep="")'],
        capture_output=True, text=True
    )
    return result.stdout.strip()

def get_jmvcore_path(jamovi_path):
    """Find jmvcore library path."""
    base_r = os.path.join(jamovi_path, "Resources", "modules", "base", "R")
    r_lib = os.path.join(jamovi_path, "Frameworks", "R", "library")
    paths = []
    if os.path.exists(base_r):
        paths.append(base_r)
    if os.path.exists(r_lib):
        paths.append(r_lib)
    return paths

def install_dependencies(rscript, lib_path, extra_lib_paths):
    """Install all required R packages."""
    lib_paths_r = "', '".join([p.replace("\\", "/") for p in [lib_path] + extra_lib_paths])

    r_code = f"""
lib <- '{lib_path.replace(os.sep, "/")}'
.libPaths(c('{lib_paths_r}'))

# Direct imports from MVN DESCRIPTION
needed <- c('R6','nortest','moments','car','dplyr','tidyr','purrr',
            'stringr','ggplot2','viridis','cli','energy','plotly','mice')

# Check which are missing (skip base R packages: methods, MASS, boot, stats, etc.)
missing <- c()
for(p in needed) {{
  if(!requireNamespace(p, quietly=TRUE)) {{
    missing <- c(missing, p)
  }}
}}

if(length(missing) > 0) {{
  cat('Installing', length(missing), 'packages:', paste(missing, collapse=', '), '\\n')
  install.packages(missing, lib=lib, repos='https://cran.r-project.org',
                   type='binary', quiet=TRUE, dependencies=TRUE)
}}

# Verify all recursive dependencies are available
all_installed <- installed.packages(lib.loc=.libPaths())
deps <- tools::package_dependencies(needed, db=available.packages(repos='https://cran.r-project.org'),
                                     recursive=TRUE)
all_deps <- unique(unlist(deps))
still_missing <- c()
for(p in all_deps) {{
  if(!requireNamespace(p, quietly=TRUE)) {{
    still_missing <- c(still_missing, p)
  }}
}}
if(length(still_missing) > 0) {{
  cat('Installing', length(still_missing), 'additional dependencies\\n')
  install.packages(still_missing, lib=lib, repos='https://cran.r-project.org',
                   type='binary', quiet=TRUE)
}}

cat('All dependencies installed.\\n')
"""
    print("Installing R package dependencies...")
    result = subprocess.run([rscript, "-e", r_code], capture_output=True, text=True)
    if result.stdout:
        print(result.stdout)
    if result.returncode != 0:
        print("STDERR:", result.stderr)
        sys.exit(1)

def install_mvn(rcmd, source_path, lib_path, extra_lib_paths):
    """Install MVN package from source."""
    print("Installing MVN from source...")
    env = os.environ.copy()
    env["R_LIBS"] = ";".join([lib_path] + extra_lib_paths)

    result = subprocess.run(
        [rcmd, "INSTALL", "--no-byte-compile", "--no-multiarch",
         f"--library={lib_path}", source_path],
        capture_output=True, text=True, env=env
    )
    if result.stdout:
        print(result.stdout)
    if result.returncode != 0:
        print("STDERR:", result.stderr)
        sys.exit(1)
    print("MVN installed successfully.")

def build_jmo(source_dir, build_dir, r_version, output_path):
    """Create the .jmo file."""
    module_dir = os.path.join(build_dir, "MVN")
    os.makedirs(module_dir, exist_ok=True)

    # Copy jamovi definition files
    jamovi_src = os.path.join(source_dir, "jamovi")

    # Create analyses directory
    analyses_dir = os.path.join(module_dir, "analyses")
    os.makedirs(analyses_dir, exist_ok=True)
    shutil.copy2(os.path.join(jamovi_src, "mvntest.a.yaml"), analyses_dir)
    shutil.copy2(os.path.join(jamovi_src, "mvntest.r.yaml"), analyses_dir)

    # Build UI from .u.yaml
    ui_dir = os.path.join(module_dir, "ui")
    os.makedirs(ui_dir, exist_ok=True)
    # Copy existing compiled UI if available, otherwise the .u.yaml
    ui_js_src = os.path.join(source_dir, "build", "js", "mvntest.js")
    if os.path.exists(ui_js_src):
        shutil.copy2(ui_js_src, ui_dir)

    # Generate jamovi.yaml from 0000.yaml + rVersion
    src_yaml = os.path.join(jamovi_src, "0000.yaml")
    with open(src_yaml, 'r', encoding='utf-8') as f:
        yaml_content = f.read()

    # Add rVersion before the closing ...
    yaml_content = yaml_content.replace("\n...\n", f"\nrVersion: {r_version}-x64\n\n...\n")

    with open(os.path.join(module_dir, "jamovi.yaml"), 'w', encoding='utf-8') as f:
        f.write(yaml_content)

    # R/ directory is already populated by install_dependencies and install_mvn
    # Just need to move it into the module structure

    return module_dir

def create_zip(module_dir, output_path):
    """Create .jmo zip file with forward slashes."""
    print(f"Creating {output_path}...")
    with zipfile.ZipFile(output_path, 'w', zipfile.ZIP_DEFLATED) as zf:
        for root, dirs, files in os.walk(module_dir):
            for file in files:
                file_path = os.path.join(root, file)
                arcname = os.path.relpath(file_path, os.path.dirname(module_dir))
                # Ensure forward slashes
                arcname = arcname.replace(os.sep, '/')
                zf.write(file_path, arcname)

    size_mb = os.path.getsize(output_path) / (1024 * 1024)
    print(f"Created: {output_path} ({size_mb:.1f} MB)")

def main():
    if len(sys.argv) < 2:
        print("Usage: python build_jmo.py <jamovi_install_path>")
        print('Example: python build_jmo.py "C:/Program Files/jamovi 2.6.19.0"')
        sys.exit(1)

    jamovi_path = sys.argv[1]
    if not os.path.exists(jamovi_path):
        print(f"ERROR: Jamovi not found at {jamovi_path}")
        sys.exit(1)

    # Script directory = source directory
    script_dir = os.path.dirname(os.path.abspath(__file__))
    source_dir = os.path.join(script_dir, "MVN_jamovi-master")
    if not os.path.exists(source_dir):
        print(f"ERROR: Source not found at {source_dir}")
        sys.exit(1)

    # Find R
    rscript, rcmd = find_r(jamovi_path)
    r_version = get_r_version(rscript)
    print(f"Jamovi path: {jamovi_path}")
    print(f"R version: {r_version}")

    extra_lib_paths = get_jmvcore_path(jamovi_path)

    # Create temp build directory
    build_dir = os.path.join(script_dir, "build_temp")
    if os.path.exists(build_dir):
        shutil.rmtree(build_dir)

    module_dir = os.path.join(build_dir, "MVN")
    r_lib_dir = os.path.join(module_dir, "R")
    os.makedirs(r_lib_dir, exist_ok=True)

    # Step 1: Install dependencies
    install_dependencies(rscript, r_lib_dir, extra_lib_paths)

    # Step 2: Install MVN from source
    install_mvn(rcmd, source_dir, r_lib_dir, extra_lib_paths)

    # Step 3: Copy jamovi module files
    # analyses
    analyses_dir = os.path.join(module_dir, "analyses")
    os.makedirs(analyses_dir, exist_ok=True)
    jamovi_src = os.path.join(source_dir, "jamovi")
    for f in ["mvntest.a.yaml", "mvntest.r.yaml"]:
        shutil.copy2(os.path.join(jamovi_src, f), analyses_dir)

    # ui - need compiled .js file
    ui_dir = os.path.join(module_dir, "ui")
    os.makedirs(ui_dir, exist_ok=True)
    # Check if compiled UI exists in current installed module
    existing_ui = os.path.join(
        os.environ.get("APPDATA", ""), "jamovi", "modules", "MVN", "ui", "mvntest.js"
    )
    if os.path.exists(existing_ui):
        shutil.copy2(existing_ui, ui_dir)
    else:
        # Generate from .u.yaml using jmvcore
        u_yaml = os.path.join(jamovi_src, "mvntest.u.yaml")
        if os.path.exists(u_yaml):
            shutil.copy2(u_yaml, ui_dir)

    # jamovi.yaml
    src_yaml = os.path.join(jamovi_src, "0000.yaml")
    with open(src_yaml, 'r', encoding='utf-8') as f:
        yaml_content = f.read()
    yaml_content = yaml_content.replace("\n...\n", f"\nrVersion: {r_version}-x64\n\n...\n")
    with open(os.path.join(module_dir, "jamovi.yaml"), 'w', encoding='utf-8') as f:
        f.write(yaml_content)

    # jamovi-full.yaml (generate from jamovi.yaml + analyses + ui inline)
    # For simplicity, copy jamovi.yaml as jamovi-full.yaml
    # (jamovi can work with just jamovi.yaml)
    shutil.copy2(os.path.join(module_dir, "jamovi.yaml"),
                 os.path.join(module_dir, "jamovi-full.yaml"))

    # Step 4: Create .jmo
    r_version_short = r_version.replace(".", "")
    pkg_version = "6.3.0"
    output_name = f"MVN_{pkg_version}_R{r_version}.jmo"
    output_path = os.path.join(script_dir, output_name)
    create_zip(module_dir, output_path)

    # Cleanup
    shutil.rmtree(build_dir)

    print(f"\nBuild complete! Output: {output_name}")
    print(f"Install in jamovi: Modules > Sideload > select {output_name}")

if __name__ == "__main__":
    main()
