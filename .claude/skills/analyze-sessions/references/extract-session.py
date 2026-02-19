#!/usr/bin/env python3
"""
Extract structured data from a Claude Code session JSONL file.
Produces a compact JSON summary suitable for qualitative analysis by a subagent.

Usage:
    python3 extract-session.py <session.jsonl> <output.json>
    python3 extract-session.py --batch <sessions-list.json> <output-dir>
"""

import json
import os
import sys
import re
from collections import Counter, defaultdict
from datetime import datetime


def extract_session(fpath, max_lines=20000):
    """Extract structured data from a single session JSONL file."""

    tools = Counter()
    skills = []
    agents_spawned = []
    user_messages = []
    assistant_text_samples = []
    files_read = []
    files_edited = []
    files_written = []
    bash_commands = []
    errors = []
    phx_commands = []
    tidewave_calls = Counter()
    mcp_calls = Counter()
    timestamps = []

    line_count = 0
    msg_types = Counter()

    with open(fpath) as f:
        for line in f:
            line_count += 1
            if line_count > max_lines:
                break

            try:
                obj = json.loads(line)
            except:
                continue

            msg_type = obj.get('type', 'unknown')
            msg_types[msg_type] += 1

            # Track timestamps
            ts = obj.get('timestamp')
            if ts:
                timestamps.append(ts)

            msg = obj.get('message', {})
            if not isinstance(msg, dict):
                continue

            content = msg.get('content', '')
            role = msg.get('role', '')

            # === USER MESSAGES ===
            if role == 'user' and isinstance(content, list):
                for block in content:
                    if isinstance(block, dict) and block.get('type') == 'text':
                        text = block.get('text', '')
                        # Skip system reminders
                        if text.startswith('<system-reminder>') or text.startswith('<command-name>'):
                            continue
                        if len(text) > 10:
                            user_messages.append(text[:500])
                        # Extract /phx: commands (filter SKILL.md template noise)
                        if not text.startswith('Base directory for this skill:'):
                            cmds = re.findall(r'/phx:\w+(?:\s+[^\n]{0,100})?', text)
                            # Filter template placeholders
                            cmds = [c for c in cmds if '{feature}' not in c
                                    and '{slug}' not in c and '<--' not in c]
                            phx_commands.extend(cmds)

            # === ASSISTANT MESSAGES ===
            if role == 'assistant' and isinstance(content, list):
                for block in content:
                    if not isinstance(block, dict):
                        continue

                    # Text content (assistant's reasoning/communication)
                    if block.get('type') == 'text':
                        text = block.get('text', '')
                        if len(text) > 20 and not text.startswith('<'):
                            assistant_text_samples.append(text[:300])

                    # Tool uses
                    if block.get('type') == 'tool_use':
                        name = block.get('name', '')
                        inp = block.get('input', {})
                        tools[name] += 1

                        # Track specific tools
                        if name == 'Read':
                            fp = inp.get('file_path', '')
                            if fp:
                                files_read.append(fp)

                        elif name == 'Edit':
                            fp = inp.get('file_path', '')
                            if fp:
                                files_edited.append(fp)

                        elif name == 'Write':
                            fp = inp.get('file_path', '')
                            if fp:
                                files_written.append(fp)

                        elif name == 'Bash':
                            cmd = inp.get('command', '')
                            desc = inp.get('description', '')
                            if cmd:
                                bash_commands.append({
                                    'command': cmd[:200],
                                    'description': desc[:100]
                                })

                        elif name == 'Skill':
                            skill = inp.get('skill', '')
                            args = inp.get('args', '')
                            skills.append({'skill': skill, 'args': args[:200] if args else ''})

                        elif name == 'Task':
                            agent_type = inp.get('subagent_type', '')
                            desc = inp.get('description', '')
                            prompt_preview = inp.get('prompt', '')[:200] if inp.get('prompt') else ''
                            agents_spawned.append({
                                'type': agent_type,
                                'description': desc,
                                'prompt_preview': prompt_preview
                            })

                        elif name.startswith('mcp__tidewave'):
                            tidewave_calls[name] += 1

                        elif name.startswith('mcp__'):
                            mcp_calls[name] += 1

                    # Tool results with errors
                    if block.get('type') == 'tool_result' and block.get('is_error'):
                        err_content = block.get('content', '')
                        if isinstance(err_content, str) and len(err_content) > 5:
                            errors.append(err_content[:200])

    # Compute duration
    duration_minutes = None
    if len(timestamps) >= 2:
        try:
            # Try parsing ISO timestamps
            first = timestamps[0]
            last = timestamps[-1]
            if isinstance(first, str) and isinstance(last, str):
                t1 = datetime.fromisoformat(first.replace('Z', '+00:00'))
                t2 = datetime.fromisoformat(last.replace('Z', '+00:00'))
                duration_minutes = round((t2 - t1).total_seconds() / 60, 1)
            elif isinstance(first, (int, float)) and isinstance(last, (int, float)):
                duration_minutes = round((last - first) / 60000, 1)  # milliseconds
        except:
            pass

    # Categorize edited files by type
    file_categories = Counter()
    for fp in files_edited:
        if '_live.ex' in fp or '_live/' in fp:
            file_categories['liveview'] += 1
        elif '_test.exs' in fp:
            file_categories['test'] += 1
        elif '/migrations/' in fp:
            file_categories['migration'] += 1
        elif '_worker.ex' in fp or '/workers/' in fp:
            file_categories['oban_worker'] += 1
        elif '/contexts/' in fp or (fp.endswith('.ex') and '/lib/' in fp):
            file_categories['context_or_module'] += 1
        elif fp.endswith('.heex'):
            file_categories['template'] += 1
        elif 'router.ex' in fp:
            file_categories['router'] += 1
        elif fp.endswith('.js') or fp.endswith('.ts'):
            file_categories['javascript'] += 1
        elif fp.endswith('.css'):
            file_categories['css'] += 1
        else:
            file_categories['other'] += 1

    # Identify mix commands
    mix_commands = [b for b in bash_commands if 'mix ' in b.get('command', '')]
    git_commands = [b for b in bash_commands if b.get('command', '').startswith('git ')]

    return {
        'session_id': os.path.basename(fpath).replace('.jsonl', ''),
        'file_size_kb': os.path.getsize(fpath) // 1024,
        'line_count': line_count,
        'truncated': line_count >= max_lines,
        'duration_minutes': duration_minutes,
        'message_types': dict(msg_types),
        'user_message_count': len(user_messages),
        'user_messages': user_messages[:30],  # Cap at 30
        'phx_commands': phx_commands,
        'tool_usage': dict(tools.most_common(30)),
        'skills_invoked': skills,
        'agents_spawned': agents_spawned,
        'files_edited': list(set(files_edited))[:50],
        'files_written': list(set(files_written))[:20],
        'file_categories': dict(file_categories),
        'bash_commands_sample': bash_commands[:30],
        'mix_commands': [m['command'] for m in mix_commands][:20],
        'git_commands': [g['command'] for g in git_commands][:10],
        'tidewave_usage': dict(tidewave_calls),
        'mcp_usage': dict(mcp_calls),
        'errors': errors[:15],
        'assistant_samples': assistant_text_samples[:10],
    }


def run_batch(sessions_file, output_dir):
    """Process all sessions from a sessions list file."""
    with open(sessions_file) as f:
        sessions = json.load(f)

    os.makedirs(output_dir, exist_ok=True)

    results = []
    for i, session in enumerate(sessions):
        fpath = session['file']
        project = session['project']
        sid = session['session_id']

        print(f"[{i+1}/{len(sessions)}] {project}/{sid[:12]}... ", end='', flush=True)

        try:
            data = extract_session(fpath)
            data['project'] = project

            # Write individual report
            out_path = os.path.join(output_dir, f"{project}_{sid[:12]}.json")
            with open(out_path, 'w') as f:
                json.dump(data, f, indent=2)

            results.append({
                'project': project,
                'session_id': sid,
                'file': out_path,
                'size_kb': data['file_size_kb'],
                'user_msgs': data['user_message_count'],
                'tools': sum(data['tool_usage'].values()),
                'has_phx': len(data['phx_commands']) > 0,
                'phx_commands': data['phx_commands'],
                'duration_minutes': data['duration_minutes'],
            })
            print(f"OK ({data['user_message_count']} msgs, {sum(data['tool_usage'].values())} tools)")
        except Exception as e:
            print(f"ERROR: {e}")
            results.append({
                'project': project,
                'session_id': sid,
                'error': str(e)
            })

    # Write index
    index_path = os.path.join(output_dir, '_index.json')
    with open(index_path, 'w') as f:
        json.dump(results, f, indent=2)

    print(f"\nDone: {len(results)} sessions processed")
    print(f"Index: {index_path}")
    return results


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage:")
        print("  python3 extract-session.py <session.jsonl> <output.json>")
        print("  python3 extract-session.py --batch <sessions-list.json> <output-dir>")
        sys.exit(1)

    if sys.argv[1] == '--batch':
        run_batch(sys.argv[2], sys.argv[3])
    else:
        data = extract_session(sys.argv[1])
        with open(sys.argv[2], 'w') as f:
            json.dump(data, f, indent=2)
        print(f"Extracted: {data['user_message_count']} user msgs, {sum(data['tool_usage'].values())} tool calls")
