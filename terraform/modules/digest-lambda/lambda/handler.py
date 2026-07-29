import logging
import os
import boto3
from datetime import datetime, timezone, timedelta
from collections import defaultdict

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.client("dynamodb")
ses      = boto3.client("ses", region_name=os.environ["AWS_REGION"])

AUDIT_TABLE     = os.environ["AUDIT_TABLE"]
SENDER_EMAIL    = os.environ["SENDER_EMAIL"]
RECIPIENT_EMAIL = os.environ["RECIPIENT_EMAIL"]


def handler(event, _context):
    now      = datetime.now(timezone.utc)
    week_ago = now - timedelta(days=7)
    logger.info("Generating weekly digest %s → %s", week_ago.date(), now.date())

    items = _scan_all(week_ago)
    created, updated = [], []

    for item in items:
        ca_str = item.get("created_at", {}).get("S", "")
        ua_str = item.get("updated_at", {}).get("S", "")
        if not ca_str:
            continue
        try:
            ca = datetime.fromisoformat(ca_str)
            ua = datetime.fromisoformat(ua_str) if ua_str else ca
        except ValueError:
            continue

        entry = {
            "industry": item.get("Industry", {}).get("S") or "Unknown",
            "client":   item.get("Client",   {}).get("S") or "Unknown",
        }
        if ca >= week_ago:
            created.append(entry)
        elif ua >= week_ago:
            updated.append(entry)

    html = _build_html(_aggregate(created), _aggregate(updated), week_ago, now)

    ses.send_email(
        Source=SENDER_EMAIL,
        Destination={"ToAddresses": [RECIPIENT_EMAIL]},
        Message={
            "Subject": {"Data": f"Weekly Document Digest — {now.strftime('%d %b %Y')}"},
            "Body":    {"Html": {"Data": html}},
        },
    )
    logger.info("Digest sent: %d new, %d updated", len(created), len(updated))
    return {"statusCode": 200}


INDUSTRIES = [
    "FSI", "PRD - Automotive", "PRD - Life Science", "PRD - Industrial",
    "PRD - Consumer Goods", "CMT", "H&PS", "RES", "Other",
]


def _scan_all(week_ago):
    items = []
    for industry in INDUSTRIES:
        kwargs = {
            "TableName": AUDIT_TABLE,
            "IndexName": "Industry-updated_at-index",
            "KeyConditionExpression": "Industry = :ind AND updated_at >= :week_ago",
            "ExpressionAttributeValues": {
                ":ind":      {"S": industry},
                ":week_ago": {"S": week_ago.isoformat()},
            },
        }
        while True:
            resp = dynamodb.query(**kwargs)
            items.extend(resp.get("Items", []))
            if "LastEvaluatedKey" not in resp:
                break
            kwargs["ExclusiveStartKey"] = resp["LastEvaluatedKey"]
    return items


def _aggregate(entries):
    counts = defaultdict(lambda: defaultdict(int))
    for e in entries:
        counts[e["industry"]][e["client"]] += 1
    return counts


def _th(t):
    return f"<th style='background:#e8e8e8;padding:6px 12px;border:1px solid #ccc;white-space:nowrap'>{t}</th>"


def _td(t, bold=False):
    inner = f"<b>{t}</b>" if bold else (t if t != 0 else "")
    return f"<td style='padding:6px 12px;border:1px solid #ccc;text-align:center'>{inner}</td>"


def _table_html(counts, title):
    total = sum(v for row in counts.values() for v in row.values())
    if total == 0:
        return f"<h2>{title}</h2><p style='color:#888'>No documents this period.</p>"

    industries = sorted(counts)
    clients    = sorted({c for row in counts.values() for c in row})

    header = _th("Industry \\ Client") + "".join(_th(c) for c in clients) + _th("Total")
    rows = ""
    for ind in industries:
        row_total = sum(counts[ind].values())
        cells = "".join(_td(counts[ind].get(c, 0)) for c in clients)
        rows += (
            f"<tr><td style='padding:6px 12px;border:1px solid #ccc'><b>{ind}</b></td>"
            f"{cells}{_td(row_total, bold=True)}</tr>"
        )

    col_totals = [sum(counts[i].get(c, 0) for i in industries) for c in clients]
    footer = (
        f"<td style='padding:6px 12px;border:1px solid #ccc'><b>Total</b></td>"
        + "".join(_td(t, bold=True) for t in col_totals)
        + _td(total, bold=True)
    )

    label = f"{total} document{'s' if total != 1 else ''}"
    return f"""
<h2 style='font-family:sans-serif'>{title} <span style='color:#666;font-size:0.85em'>({label})</span></h2>
<table style='border-collapse:collapse;font-family:sans-serif;font-size:14px'>
  <thead><tr>{header}</tr></thead>
  <tbody>{rows}<tr>{footer}</tr></tbody>
</table>"""


def _build_html(created, updated, week_ago, now):
    period = f"{week_ago.strftime('%d %b')} – {now.strftime('%d %b %Y')} UTC"
    return f"""<!DOCTYPE html><html><body style='font-family:sans-serif;max-width:960px;margin:40px auto'>
<h1>Weekly Document Digest</h1>
<p style='color:#555'>Period: <b>{period}</b></p>
{_table_html(created, "New Documents")}
<br/><br/>
{_table_html(updated, "Updated Documents")}
<hr style='margin-top:40px'/>
<p style='color:#aaa;font-size:12px'>Generated automatically by the Knowledge Base platform.</p>
</body></html>"""
