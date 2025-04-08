export async function handleHome(request, env) {
  return new Response('Welcome to TUI Portfolio', {
    headers: { 'Content-Type': 'text/plain' },
  });
}

export async function handlePhotoDetail(request, env) {
  return new Response('Photo Detail Page', {
    headers: { 'Content-Type': 'text/plain' },
  });
}