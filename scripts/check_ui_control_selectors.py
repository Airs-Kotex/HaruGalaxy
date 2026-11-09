#!/usr/bin/env python3
"""Verify that MWEdgeHandle overrides UIKit's Objective-C UIControl selectors."""
import argparse
import re
import subprocess


REQUIRED = (
    "beginTrackingWithTouch:withEvent:",
    "continueTrackingWithTouch:withEvent:",
    "endTrackingWithTouch:withEvent:",
    "cancelTrackingWithEvent:",
)
FORBIDDEN = (
    "beginTracking:withEvent:",
    "continueTracking:withEvent:",
    "endTracking:withEvent:",
)


def class_section(ast, declaration, name):
    for candidate in re.split(r"(?m)^Dumping [^\n]+:\n", ast):
        first = candidate.splitlines()[:1]
        if first and re.search(r"\b" + declaration + r"\b.*\b" + name + r"\b", first[0]):
            return candidate
    raise ValueError(f"Missing {declaration} for {name}")


def direct_methods(ast, declaration, name):
    """Return direct methods from a single class AST, excluding inherited APIs."""
    section = class_section(ast, declaration, name)
    return dict(re.findall(
        r"(?m)^[|`]-(?:ObjCMethodDecl)[^\n]*? - (\S+) '([^']+)'", section))


def check_super_cleanup(ast):
    section = class_section(ast, "ObjCImplementationDecl", "MWEdgeHandle")
    blocks = re.findall(r"(?ms)^[|`]-ObjCMethodDecl .*?(?=^[|`]-|\Z)", section)
    for selector in REQUIRED[2:]:
        method = next((block for block in blocks if f" - {selector} '" in block.splitlines()[0]), "")
        if not re.search(r"selector=" + re.escape(selector) + r" super \(instance\)", method):
            raise ValueError(f"UIControl cleanup contract failed; missing super call in {selector}")


def check_contract(handle_methods, sdk_methods):
    missing = [selector for selector in REQUIRED if selector not in handle_methods]
    stale = [selector for selector in FORBIDDEN if selector in handle_methods]
    mismatch = [selector for selector in REQUIRED if selector in handle_methods and
                handle_methods[selector] != sdk_methods.get(selector)]
    if missing or stale or mismatch:
        raise ValueError(f"UIControl selector contract failed; missing={missing}, stale={stale}, type_mismatch={mismatch}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--clang", required=True)
    parser.add_argument("--sdk", required=True)
    parser.add_argument("--source", default="Sources/UI/MWEdgeHandle.m")
    parser.add_argument("--deployment", default="14.0")
    args = parser.parse_args()
    command = [
        args.clang,
        "-fsyntax-only",
        "-target", f"arm64-apple-ios{args.deployment}",
        "-isysroot", args.sdk,
        "-fobjc-arc", "-fblocks", "-fobjc-exceptions",
        "-Wno-deprecated-declarations",
        "-Xclang", "-ast-dump",
    ]
    methods = []
    implementation_ast = None
    for name, declaration in (("MWEdgeHandle", "ObjCImplementationDecl"), ("UIControl", "ObjCInterfaceDecl")):
        result = subprocess.run([*command, "-Xclang", "-ast-dump-filter=" + name, args.source],
                                text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if result.returncode:
            raise SystemExit(result.stderr or f"Clang could not parse {name}")
        try:
            methods.append(direct_methods(result.stdout, declaration, name))
            if name == "MWEdgeHandle":
                implementation_ast = result.stdout
        except ValueError as error:
            raise SystemExit(str(error)) from error
    try:
        check_contract(*methods)
        check_super_cleanup(implementation_ast)
    except ValueError as error:
        raise SystemExit(str(error)) from error
    print("PASS: compiled entry implements SDK UIControl callbacks and calls superclass end/cancel cleanup")


if __name__ == "__main__":
    main()
