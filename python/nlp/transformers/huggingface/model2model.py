'''
Model2Model example
'''
import torch
from transformers import BertTokenizer, Model2Model

# OPTIONAL: if you want to have more information on what's happening under the hood, activate the logger as follows
import logging
logging.basicConfig(level=logging.INFO)

# Load pre-trained model tokenizer (vocabulary)
tokenizer = BertTokenizer.from_pretrained('bert-base-uncased')

# Encode the input to the encoder (the question)
question = "Who was Jim Henson?"
encoded_question = tokenizer.encode(question)

# Encode the input to the decoder (the answer)
answer = "Jim Henson was a puppeteer"
encoded_answer = tokenizer.encode(answer)

# Convert inputs to PyTorch tensors
question_tensor = torch.tensor([encoded_question])
answer_tensor = torch.tensor([encoded_answer])

'''
Use Model2Model to get the value of the loss associated with this (question, answer) pair
'''

# In order to compute the loss we need to provide language model
# labels (the token ids that the model should have produced) to
# the decoder.
lm_labels =  encoded_answer
labels_tensor = torch.tensor([lm_labels])

# Load pre-trained model (weights)
model = Model2Model.from_pretrained('bert-base-uncased')

# Set the model in evaluation mode to deactivate the DropOut modules
# This is IMPORTANT to have reproducible results during evaluation!
model.eval()

# Predict hidden states features for each layer
with torch.no_grad():
    # See the models docstrings for the detail of the inputs
    outputs = model(question_tensor, answer_tensor, decoder_lm_labels=labels_tensor)
    # Transformers models always output tuples.
    # See the models docstrings for the detail of all the outputs
    # In our case, the first element is the value of the LM loss 
    lm_loss = outputs[0]
