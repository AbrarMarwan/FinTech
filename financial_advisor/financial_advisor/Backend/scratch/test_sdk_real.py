from openrouter import OpenRouter
import os
from dotenv import load_dotenv

# Run from Backend directory
load_dotenv(dotenv_path=".env")
api_key = os.getenv("OPENROUTER_API_KEY")

print(f"API Key found: {'Yes' if api_key else 'No'}")
if api_key:
    print(f"API Key starts with: {api_key[:10]}...")

try:
    with OpenRouter(api_key=api_key) as client:
        response = client.chat.send(
            model="openai/gpt-4o-mini",
            messages=[
                {"role": "user", "content": "Say hello!"}
            ]
        )
        if hasattr(response, 'choices') and response.choices:
            print("Response:", response.choices[0].message.content)
        else:
            print("No choices in response:", response)
except Exception as e:
    print("Error:", e)
