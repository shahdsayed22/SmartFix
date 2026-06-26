import { start } from 'workflow/api';
import { triageIssue } from '@/workflows/issue-triage';
import { NextResponse } from 'next/server';

// POST /api/workflows/issue-triage  { "issueId": "<mongo _id>" }
// Manually (re)trigger the durable AI triage pipeline for an issue.
export async function POST(request) {
  try {
    const { issueId } = await request.json();
    if (!issueId) {
      return NextResponse.json({ error: 'issueId is required' }, { status: 400 });
    }

    // start() returns immediately; the workflow runs asynchronously and durably.
    const run = await start(triageIssue, [issueId]);

    return NextResponse.json({
      message: 'Issue triage workflow started',
      runId: run.runId,
      issueId,
    });
  } catch (error) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }
}
