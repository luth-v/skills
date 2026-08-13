#!/usr/bin/env python3
"""Filter CLI agent stream-json/JSONL into human progress lines + final result.

stdin:  JSONL from claude/cursor stream-json, codex --json, or opencode JSON
stdout: final result text only (parent contract)
stderr: human progress lines (tee'd to --log by caller or here), including one
        machine-parseable `SESSION=<id>` line as soon as the id is known
        (codex thread_id / claude+cursor session_id / opencode sessionID)

Usage:
  live-log.py --harness claude|codex|cursor|opencode --log /path/to.log
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from typing import Any

CRUMB_LEN = 120
RAW_LEN = 200


def crumb(text: str, limit: int = CRUMB_LEN) -> str:
    text = " ".join(text.split())
    if len(text) <= limit:
        return text
    return text[: limit - 1] + "…"


def error_text(value: Any) -> str:
    if isinstance(value, dict) and "message" in value:
        return str(value["message"])
    return str(value)


def tool_summary(name: str, inp: Any) -> str:
    if not isinstance(inp, dict):
        return name
    for key in ("file_path", "path", "target_notebook", "filePath"):
        val = inp.get(key)
        if isinstance(val, str) and val:
            return f"{name} {val}"
    cmd = inp.get("command")
    if isinstance(cmd, str) and cmd:
        return f"{name} {crumb(cmd, 80)}"
    pattern = inp.get("pattern") or inp.get("glob_pattern") or inp.get("query")
    if isinstance(pattern, str) and pattern:
        return f"{name} {crumb(pattern, 60)}"
    return name


class LiveLog:
    def __init__(self, harness: str, log_path: str) -> None:
        self.harness = harness
        self.log_path = log_path
        self.final_result: str | None = None
        self.session_id: str | None = None
        self._assistant_buf: list[str] = []
        self._opencode_step_text: list[str] = []
        self._opencode_tools_started: set[str] = set()
        self._log_fp = open(log_path, "a", encoding="utf-8")  # noqa: SIM115
        # Header (LOG=) already written by setup-live-log.sh; note filter pid only
        self._emit_progress(f"live-log pid={os.getpid()} harness={harness}")

    def close(self) -> None:
        try:
            self._log_fp.close()
        except Exception:
            pass

    def _emit_progress(self, line: str) -> None:
        line = line.rstrip("\n")
        sys.stderr.write(line + "\n")
        sys.stderr.flush()
        try:
            self._log_fp.write(line + "\n")
            self._log_fp.flush()
        except Exception:
            pass

    def _note_session(self, sid: Any) -> None:
        # Machine-parseable, emitted once, as early as the harness reveals the id.
        # Parent (/let-them-cook) greps `^SESSION=` to build the handoff chain.
        if self.session_id is not None or not isinstance(sid, str) or not sid.strip():
            return
        self.session_id = sid.strip()
        self._emit_progress(f"SESSION={self.session_id}")

    def _flush_assistant_crumb(self) -> None:
        if not self._assistant_buf:
            return
        text = "".join(self._assistant_buf).strip()
        self._assistant_buf.clear()
        if text:
            self._emit_progress(f"assistant: {crumb(text)}")

    def _finalize_opencode_text(self) -> None:
        text = "".join(self._opencode_step_text).strip()
        if text:
            self.final_result = text
        self._opencode_step_text.clear()

    def handle_line(self, raw: str) -> None:
        raw = raw.strip()
        if not raw:
            return
        try:
            data = json.loads(raw)
        except json.JSONDecodeError:
            self._emit_progress(f"raw: {crumb(raw, RAW_LEN)}")
            return
        if not isinstance(data, dict):
            self._emit_progress(f"raw: {crumb(raw, RAW_LEN)}")
            return

        if self.harness == "codex":
            self._handle_codex(data, raw)
        elif self.harness == "opencode":
            self._handle_opencode(data, raw)
        else:
            # claude + cursor stream-json (same family)
            self._handle_claude_family(data, raw)

    def _handle_claude_family(self, data: dict[str, Any], raw: str) -> None:
        etype = data.get("type")
        # claude + cursor both stamp session_id on system/init and most later events
        self._note_session(data.get("session_id"))

        if etype == "system":
            subtype = data.get("subtype") or ""
            if subtype and subtype != "init":
                self._emit_progress(f"system: {subtype}")
            elif subtype == "init":
                model = data.get("model") or ""
                cwd = data.get("cwd") or ""
                bits = [b for b in (model, cwd) if b]
                self._emit_progress("session start" + (f" ({', '.join(bits)})" if bits else ""))
            return

        if etype == "assistant":
            msg = data.get("message") or {}
            content = msg.get("content")
            if isinstance(content, list):
                for block in content:
                    if not isinstance(block, dict):
                        continue
                    btype = block.get("type")
                    if btype == "text":
                        text = block.get("text") or ""
                        if text:
                            self._assistant_buf.append(text)
                    elif btype == "tool_use":
                        self._flush_assistant_crumb()
                        name = str(block.get("name") or "tool")
                        self._emit_progress(f"tool_start {tool_summary(name, block.get('input'))}")
                    # skip thinking
            elif isinstance(content, str) and content.strip():
                self._assistant_buf.append(content)
            return

        if etype == "user":
            self._flush_assistant_crumb()
            msg = data.get("message") or {}
            content = msg.get("content")
            if isinstance(content, list):
                for block in content:
                    if not isinstance(block, dict):
                        continue
                    if block.get("type") == "tool_result":
                        err = block.get("is_error")
                        suffix = " error" if err else ""
                        tid = block.get("tool_use_id") or ""
                        self._emit_progress(f"tool_end{suffix}" + (f" {tid}" if tid else ""))
            return

        if etype == "result":
            self._flush_assistant_crumb()
            if data.get("is_error") or data.get("subtype") == "error":
                msg = data.get("result") or data.get("error") or "error"
                self._emit_progress(f"error: {crumb(str(msg), RAW_LEN)}")
                # still capture result text if present
            result = data.get("result")
            if isinstance(result, str):
                self.final_result = result
            elif result is not None:
                self.final_result = json.dumps(result)
            cost = data.get("total_cost_usd")
            turns = data.get("num_turns")
            bits = []
            if turns is not None:
                bits.append(f"turns={turns}")
            if cost is not None:
                bits.append(f"cost_usd={cost}")
            self._emit_progress("done" + (f" ({', '.join(bits)})" if bits else ""))
            return

        if etype == "stream_event":
            # ignore partials by default (we asked not to include them)
            return

        # cursor sometimes nests differently — best-effort
        if "result" in data and data.get("type") in (None, "result"):
            result = data.get("result")
            if isinstance(result, str) and self.final_result is None:
                self.final_result = result

    def _handle_opencode(self, data: dict[str, Any], raw: str) -> None:
        etype = data.get("type")
        part = data.get("part") or {}
        if not isinstance(part, dict):
            part = {}
        # opencode stamps sessionID on every event (top level and inside part)
        self._note_session(data.get("sessionID") or part.get("sessionID"))

        if etype == "step_start":
            self._opencode_step_text.clear()
            self._emit_progress("step start")
            return

        if etype == "text":
            text = part.get("text") or data.get("text") or ""
            if isinstance(text, str) and text.strip():
                self._opencode_step_text.append(text)
                self._assistant_buf.append(text)
            return

        if etype == "tool_use":
            self._flush_assistant_crumb()
            name = str(part.get("tool") or part.get("name") or "tool")
            state = part.get("state") or {}
            if not isinstance(state, dict):
                state = {}
            call_id = str(part.get("callID") or part.get("id") or name)
            status = str(state.get("status") or "")
            summary = tool_summary(name, state.get("input") or part.get("input"))

            if call_id not in self._opencode_tools_started:
                self._emit_progress(f"tool_start {summary}")
                self._opencode_tools_started.add(call_id)

            if status in ("completed", "error", "failed"):
                suffix = ""
                metadata = state.get("metadata") or {}
                if isinstance(metadata, dict) and metadata.get("exit") is not None:
                    suffix = f" exit={metadata['exit']}"
                if status in ("error", "failed"):
                    suffix += " error"
                self._emit_progress(f"tool_end {name}{suffix}")
                self._opencode_tools_started.discard(call_id)
            return

        if etype == "step_finish":
            self._flush_assistant_crumb()
            self._finalize_opencode_text()

            reason = part.get("reason") or ""
            tokens = part.get("tokens") or {}
            bits = []
            if reason:
                bits.append(f"reason={reason}")
            if isinstance(tokens, dict):
                for key in ("input", "output", "reasoning"):
                    if tokens.get(key) is not None:
                        bits.append(f"{key}_tokens={tokens[key]}")
            self._emit_progress("step done" + (f" ({', '.join(bits)})" if bits else ""))
            return

        if etype == "error":
            msg = data.get("error") or data.get("message") or part.get("error") or raw
            self._emit_progress(f"error: {crumb(error_text(msg), RAW_LEN)}")
            return

    def _handle_codex(self, data: dict[str, Any], raw: str) -> None:
        etype = data.get("type")

        if etype == "thread.started":
            tid = data.get("thread_id") or ""
            self._emit_progress(f"session start" + (f" ({tid})" if tid else ""))
            self._note_session(tid)
            return

        if etype == "turn.started":
            self._emit_progress("turn start")
            return

        if etype == "turn.completed":
            usage = data.get("usage") or {}
            bits = []
            for k in ("input_tokens", "output_tokens"):
                if k in usage:
                    bits.append(f"{k}={usage[k]}")
            self._emit_progress("turn done" + (f" ({', '.join(bits)})" if bits else ""))
            return

        if etype == "turn.failed":
            err = data.get("error") or data
            self._emit_progress(f"turn failed: {crumb(str(err), RAW_LEN)}")
            return

        if etype == "error":
            msg = data.get("message") or data.get("error") or raw
            self._emit_progress(f"error: {crumb(str(msg), RAW_LEN)}")
            return

        if etype in ("item.started", "item.updated", "item.completed"):
            item = data.get("item") or {}
            if not isinstance(item, dict):
                return
            # tolerate type vs item_type
            itype = item.get("type") or item.get("item_type") or "item"
            phase = etype.split(".", 1)[1]  # started|updated|completed

            if itype in ("agent_message", "assistant_message"):
                if phase == "completed":
                    text = item.get("text") or ""
                    if text:
                        self._emit_progress(f"assistant: {crumb(text)}")
                        self.final_result = text
                return

            if itype == "reasoning":
                # skip thinking dumps
                return

            if itype == "command_execution":
                cmd = item.get("command") or ""
                if phase == "started":
                    self._emit_progress(f"tool_start Bash {crumb(str(cmd), 80)}")
                elif phase == "completed":
                    code = item.get("exit_code")
                    suffix = f" exit={code}" if code is not None else ""
                    self._emit_progress(f"tool_end Bash{suffix}")
                return

            if itype == "file_change":
                if phase == "completed":
                    changes = item.get("changes") or item.get("files") or []
                    paths: list[str] = []
                    if isinstance(changes, list):
                        for ch in changes[:5]:
                            if isinstance(ch, dict):
                                p = ch.get("path") or ch.get("file") or ""
                                kind = ch.get("kind") or ch.get("type") or ""
                                if p:
                                    paths.append(f"{kind}:{p}" if kind else p)
                            elif isinstance(ch, str):
                                paths.append(ch)
                    if paths:
                        self._emit_progress(f"file_change {', '.join(paths)}")
                    else:
                        self._emit_progress("file_change")
                elif phase == "started":
                    self._emit_progress("tool_start file_change")
                return

            if itype in ("mcp_tool_call", "web_search", "todo_list"):
                if phase == "started":
                    detail = item.get("name") or item.get("query") or itype
                    self._emit_progress(f"tool_start {crumb(str(detail), 80)}")
                elif phase == "completed":
                    self._emit_progress(f"tool_end {itype}")
                return

            if itype == "error":
                msg = item.get("message") or item.get("text") or itype
                self._emit_progress(f"error: {crumb(str(msg), RAW_LEN)}")
                return

            if phase == "started":
                self._emit_progress(f"tool_start {itype}")
            elif phase == "completed":
                self._emit_progress(f"tool_end {itype}")
            return


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--harness", required=True, choices=("claude", "codex", "cursor", "opencode")
    )
    parser.add_argument("--log", required=True, help="progress log path")
    args = parser.parse_args()

    log = LiveLog(args.harness, args.log)
    try:
        for line in sys.stdin:
            log.handle_line(line)
        log._flush_assistant_crumb()
        if args.harness == "opencode":
            log._finalize_opencode_text()
    finally:
        log.close()

    if log.final_result is None:
        sys.stderr.write("live-log.py: no final result captured; see LOG\n")
        sys.stderr.flush()
        return 1

    sys.stdout.write(log.final_result)
    if not log.final_result.endswith("\n"):
        sys.stdout.write("\n")
    sys.stdout.flush()
    return 0


if __name__ == "__main__":
    sys.exit(main())
