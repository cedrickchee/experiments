# OpenAssistant inference service

The inference service is a component that answers prompts by calling the [OpenAssistant (OA)](https://github.com/LAION-AI/Open-Assistant) models.

## Systems architecture

It has a HTTP server and several workers.

The server is a Python application that communicates via gRPC with the
workers, which are the ones that use the model to carry out the inference.

The frontend (web/node.js) makes API calls to this inference service (backend).

Refer to [OA developer docs](https://projects.laion.ai/Open-Assistant/docs/guides/developers) to learn more.

## What's inside

This project provides a starter kit to run a variety of OA models.

Pre-release (alpha-ish) models and family:
- Chip2: version 6
- Joi: version 5
- Chip: version 4
- Rosey: version 3

## Dependencies

Install Python packages:

- PyTorch
- [bitsandbytes](https://bitsandbytes.readthedocs.io/en/latest/) - 8-bit optimizers
- Sanic - Python web server and web framework

## Deployment

This starter kit currently deploy the inference service container on AWS Fargate
(serverless compute engine).

First, build the container image using the `Dockerfile`.

Push the image to AWS container registry.
