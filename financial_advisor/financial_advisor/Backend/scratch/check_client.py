from openrouter import OpenRouter
with OpenRouter(api_key="test") as client:
    print(f"Client: {client}")
    print(f"Client dir: {dir(client)}")
    if hasattr(client, 'chat'):
        print(f"Chat dir: {dir(client.chat)}")
