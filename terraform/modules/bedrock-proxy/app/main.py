"""
Bedrock Agent → OpenAI-compatible proxy.

Open WebUI (and any OpenAI-format client) sends requests to POST /v1/chat/completions.
This proxy translates them to bedrock-agent-runtime:InvokeAgent, collects the streaming
response, formats inline citations, and returns an OpenAI-compatible JSON response.
"""

import os
import uuid
import logging
import boto3
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

logging.basicConfig(level=logging.INFO)
log = logging.getLogger(__name__)

AGENT_ID       = os.environ["BEDROCK_AGENT_ID"]
AGENT_ALIAS_ID = os.environ["BEDROCK_AGENT_ALIAS_ID"]
AWS_REGION     = os.environ.get("AWS_REGION", "eu-central-1")

bedrock = boto3.client("bedrock-agent-runtime", region_name=AWS_REGION)

app = FastAPI(title="Bedrock Agent Proxy")


class Message(BaseModel):
    role: str
    content: str


class ChatRequest(BaseModel):
    model: str = "bedrock-agent"
    messages: list[Message]
    stream: bool = False


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/v1/chat/completions")
def chat(req: ChatRequest):
    user_msg = next((m.content for m in reversed(req.messages) if m.role == "user"), "")
    if not user_msg:
        raise HTTPException(status_code=400, detail="No user message in request")

    session_id = str(uuid.uuid4())
    log.info("invoke_agent session=%s agent=%s alias=%s", session_id, AGENT_ID, AGENT_ALIAS_ID)

    try:
        response = bedrock.invoke_agent(
            agentId=AGENT_ID,
            agentAliasId=AGENT_ALIAS_ID,
            sessionId=session_id,
            inputText=user_msg,
        )
    except bedrock.exceptions.ThrottlingException as exc:
        log.warning("Bedrock throttled: %s", exc)
        raise HTTPException(status_code=429, detail="Bedrock agent is throttled — retry shortly")
    except Exception as exc:
        log.error("invoke_agent failed: %s", exc)
        raise HTTPException(status_code=502, detail=f"Bedrock agent error: {exc}")

    answer_parts: list[str] = []
    seen_citations: list[str] = []

    for event in response.get("completion", []):
        if "chunk" not in event:
            continue
        chunk = event["chunk"]
        answer_parts.append(chunk["bytes"].decode("utf-8"))

        for citation in chunk.get("attribution", {}).get("citations", []):
            for ref in citation.get("retrievedReferences", []):
                uri  = ref.get("location", {}).get("s3Location", {}).get("uri", "")
                name = uri.split("/")[-1] if uri else "unknown"
                page = ref.get("metadata", {}).get(
                    "x-amz-bedrock-kb-source-uri-page-number", ""
                )
                page_str = f", Page {page}" if page else ""
                label = f"[Source: {name}{page_str}]"
                if label not in seen_citations:
                    seen_citations.append(label)

    answer = "".join(answer_parts)
    if seen_citations:
        answer += "\n\n" + "  ".join(seen_citations)

    return {
        "id": f"chatcmpl-{session_id}",
        "object": "chat.completion",
        "model": "bedrock-agent",
        "choices": [{
            "index": 0,
            "message": {"role": "assistant", "content": answer},
            "finish_reason": "stop",
        }],
        "usage": {"prompt_tokens": 0, "completion_tokens": 0, "total_tokens": 0},
    }
