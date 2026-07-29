export async function callApi(url: string, options?: RequestInit) {
  const response = await fetch(url, options);
  const contentType = response.headers.get('content-type') ?? '';
  if (response.redirected || !contentType.includes('application/json')) {
    // ALB session expired → force full navigation to trigger Cognito re-auth.
    // Guard against calling this from the root page itself to prevent a reload loop.
    if (typeof window !== 'undefined' && window.location.pathname !== '/') {
      window.location.href = '/';
    }
    return undefined;
  }
  return response.json();
}
