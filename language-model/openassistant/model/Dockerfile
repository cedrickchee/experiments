FROM pytorch/pytorch:1.11.0-cuda11.3-cudnn8-devel

WORKDIR /

RUN rm /etc/apt/sources.list.d/cuda.list
RUN rm /etc/apt/sources.list.d/nvidia-ml.list

RUN apt-get update && apt-get install -y git

RUN pip3 install --upgrade pip
ADD requirements.txt requirements.txt
RUN pip3 install -r requirements.txt

# Download model weight files
ADD download.py .
RUN python3 download.py

ADD server.py .
ADD app.py .

EXPOSE 3000

CMD python3 -u server.py
