import { useState } from 'react'
import { fetchNui } from './fetch'
import './dialogue.css'

function Dialogue() {
  const [dialogueOptions, setDialogueOption] = useState([])
  const [currentText, setCurrentText] = useState("Welcome traveler! How can I help you today?")
  const [speakerName, setSpeakerName] = useState("Friendly NPC")

  const handleMessage = (event) => {
    var data = event.data;

    if (data !== undefined && data.type === "close") {
      document.getElementById('root').classList.add("hidden");
    }
    if (data !== undefined && data.type === "open") {
      setDialogueOption(data.options);
      setCurrentText(data.text);
      setSpeakerName(data.name);
      document.getElementById('root').classList.remove("hidden");
      
    }
  };

  window.addEventListener("message", handleMessage);

  return (
    <>
      <div className="container">        
        {/* Dialogue System */}
        <div className="dialogue-container">
          <h2>{speakerName}</h2>
          <div className="dialogue-text">
            <p>{currentText}</p>
          </div>
          <div className="dialogue-options">
            {dialogueOptions.map((option) => (
              <button 
                key={option.id}
                onClick={() => fetchNui("dialogue:SelectOption", { name: speakerName, id: option.id })}
                className="dialogue-button"
              >
                {option.label}
              </button>
            ))}
          </div>
        </div>
      </div>
    </>
  )
}

export default Dialogue
