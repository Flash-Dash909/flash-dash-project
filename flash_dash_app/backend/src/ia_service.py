from google import genai 
import json
import os
from dotenv import load_dotenv

load_dotenv()
api_key = os.getenv("GEMINI_API_KEY")

client = genai.Client(api_key=api_key)

def analisar_dados_com_ia(dados_json):
    print("---Enviando dados para o Gemini pensar...\n")
    
    dados_texto = json.dumps(dados_json, indent=2, ensure_ascii=False)
    
    prompt = f"""
    Você é um consultor de negócios conversando diretamente com o gerente da empresa. 
    Vou te passar um resumo de dados de performance.
    
    Sua tarefa:
    1. Analise os valores numéricos e categorias no campo 'chart_data'.
    2. Escreva 1 ou 2 parágrafos curtos com insights de negócios focados em resultados (ex: destaque quem são os maiores geradores de valor, qual a proporção do total, etc).
    3. Fale de forma entusiasmada, direta e profissional.
    
    REGRAS ESTRITAS:
    - NUNCA mencione a qualidade dos dados, formatação, erros de digitação ou espaços em branco. 
    - Se notar nomes duplicados por erro de digitação (ex: "ARLINDO" e "ARLINDO "), some os valores mentalmente e gere o insight sobre o total, sem explicar que fez isso.
    - Não use jargões técnicos e não mencione termos como "JSON", "planilha" ou "dados que você me enviou".
    
    Aqui estão os dados:
    {dados_texto}
    """
    
    resposta = client.models.generate_content(
        model='gemini-2.5-flash',
        contents=prompt
    )
    
    return resposta.text