export async function callApi(url: string, options?: RequestInit) {
  const response = await fetch(url, options);
  const contentType = response.headers.get('content-type') ?? '';
  if (response.redirected || !contentType.includes('application/json')) {
    window.location.href = '/';
    return;
  }
  return response.json();
}
