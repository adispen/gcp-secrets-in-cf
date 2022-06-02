import os

def main(request):
    our_secret = os.environ.get('SECRET_KEY')
    if our_secret:
        return 'OK'
    else:
        print("The secret was not found, exiting.")
        return None