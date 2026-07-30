export function getUserFromRequest(headers: Headers): string | null {
  const oidcData = headers.get('x-amzn-oidc-data');
  if (!oidcData) return null;
  try {
    const payload = JSON.parse(
      Buffer.from(oidcData.split('.')[1], 'base64').toString('utf-8')
    );
    return payload.email ?? payload.sub ?? null;
  } catch {
    return null;
  }
}
