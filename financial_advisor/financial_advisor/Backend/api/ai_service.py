from openrouter import OpenRouter
import os

OPENROUTER_API_KEY = os.getenv("OPENROUTER_API_KEY", "")

def ask_ai(prompt, model):
    try:
        with OpenRouter(api_key=OPENROUTER_API_KEY) as client:
            response = client.chat.send(
                model=model,
                messages=[
                    {"role": "system", "content": "You are a financial advisor AI. Give short and useful advice."},
                    {"role": "user", "content": prompt}
                ]
            )
            # Assuming the response object has the structure suggested by previous inspections
            # and follows the typical chat completion format.
            if hasattr(response, 'choices') and response.choices:
                return response.choices[0].message.content
            return "Error from AI"
    except Exception as e:
        print(f"OpenRouter Error: {e}")
        return "Error from AI"


def smart_ai(prompt):
    models = [
        "openai/gpt-4o-mini",
        "mistralai/mistral-7b-instruct",
        "meta-llama/llama-3-8b-instruct"
    ]

    for model in models:
        try:
            response = ask_ai(prompt, model)
            if response != "Error from AI":
                return response
        except:
            continue

    return "All models failed"


def smart_route(prompt):
    if "ذهب" in prompt or "عملة" in prompt:
        return ask_ai(prompt, "mistralai/mistral-7b-instruct")
    else:
        return smart_ai(prompt)