export async function handleGetFile(request, env) {
  return new Response('File Handler', {
    headers: { 'Content-Type': 'application/octet-stream' },
  });
}