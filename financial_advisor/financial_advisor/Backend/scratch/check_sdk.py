import openrouter
print(dir(openrouter))
try:
    from openrouter import OpenRouter
    print("OpenRouter class found")
    print(dir(OpenRouter))
except ImportError:
    print("OpenRouter class NOT found")
