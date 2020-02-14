'''
Model2Model example for question answering
'''
import torch
from transformers import BertTokenizer, Model2Model

# OPTIONAL: if you want to have more information on what's happening under the hood, activate the logger as follows
import logging
logging.basicConfig(level=logging.INFO)

# Load pre-trained model tokenizer (vocabulary)
tokenizer = BertTokenizer.from_pretrained('bert-base-uncased')

'''
Assuming that we fine-tuned the model, let us now see how to generate an answer
'''

# Let's re-use the previous question
question = "Who was Jim Henson?"
encoded_question = tokenizer.encode(question)
question_tensor = torch.tensor([encoded_question])

# This time we try to generate the answer, so we start with an empty sequence
answer = "[CLS]"
encoded_answer = tokenizer.encode(answer, add_special_tokens=False)
answer_tensor = torch.tensor([encoded_answer])

# Load pre-trained model (weights)
model = Model2Model.from_pretrained('fine-tuned-weights')
model.eval()

# Predict all tokens
with torch.no_grad():
    outputs = model(question_tensor, answer_tensor)
    predictions = outputs[0]

# confirm we were able to predict 'jim'
predicted_index = torch.argmax(predictions[0, -1]).item()
predicted_token = tokenizer.convert_ids_to_tokens([predicted_index])[0]
assert predicted_token == 'jim'