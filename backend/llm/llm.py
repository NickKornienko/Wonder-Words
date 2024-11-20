from .openai_models import gpt_4o_mini

llm_type = 1


def llm(query):
    def llm_type_2(query):
        return f"Response from LLM type 2 for query: {query}"

    def llm_type_3(query):
        return f"Response from LLM type 3 for query: {query}"

    switch = {
        1: gpt_4o_mini,
        2: llm_type_2,
        3: llm_type_3,
    }

    selected_llm = switch.get(llm_type)
    response = selected_llm(query)

    return response
