#
# HTTP server
#

from sanic import Sanic, response
import subprocess
import inference

# Load the model to GPU on server startup
inference.init()

server = Sanic("oa_inference")

# Healthchecks verify that the environment is correct on AWS container
@server.route('/healthcheck', methods=["GET"])
def healthcheck(request):
    # check if GPU is visible
    gpu = False
    out = subprocess.run("nvidia-smi", shell=True)
    if out.returncode == 0:
        gpu = True

    return response.json({"state": "healthy", "gpu": gpu})

# Inference handler at '/'
@server.route('/', methods=["POST"]) 
def inference(request):
    try:
        model_inputs = response.json.loads(request.json)
    except:
        model_inputs = request.json

    output = user_src.inference(model_inputs)

    return response.json(output)


if __name__ == '__main__':
    server.run(host='0.0.0.0', port=3000, workers=1)
