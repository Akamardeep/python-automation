from flask import Flask

app = Flask(__name__)

print('amardeep') 

@app.route("/")
def hello():
    return "Hello world 4 this is fourth ecr image" 

@app.route("/ak")
def hello_ak():
    return "Hello ak!4 this is fourth ecr image" 

@app.route("/mk")
def hello_mk():
    return "Hello mk!4 this is fourth ecr image" 

if __name__ == "__main__":
    app.run()  
